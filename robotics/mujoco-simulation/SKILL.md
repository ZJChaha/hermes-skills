---
name: mujoco-simulation
description: Set up and run MuJoCo physics simulations — environment, models, controllers. Covers WSL-specific venv placement, Python 3.14+ compatibility (avoid PyBullet), MuJoCo API migration pitfalls, and template project structures.
---

# MuJoCo Simulation Setup

Use this skill when the user wants to set up a MuJoCo-based robotics simulation environment, build a mechanical arm / robot model, or run physics demos with controllers (PD, admittance, impedance, etc.).

## Trigger conditions

- "set up MuJoCo" / "install MuJoCo"
- "build a robot simulation" / "mechanical arm simulation"
- "force control demo" / "admittance control simulation"
- "MuJoCo model" / "XML robot model"

## Step 1: Environment setup

### Virtual environment placement (CRITICAL for WSL)

On WSL, **never** put the venv on a Windows-mounted drive (`/mnt/c/`, `/mnt/d/`). NTFS I/O is 10-50x slower and causes `pip install` timeouts. Always place venv on WSL native ext4:

```bash
# WRONG (will timeout):
python3 -m venv /mnt/d/project/venv

# RIGHT:
python3 -m venv ~/project_venv
```

Keep project code on the Windows drive if the user wants, but venv stays on ext4.

### Python 3.14+ compatibility: avoid PyBullet

Python 3.14 is too new for PyBullet — its C++ extensions (`btGImpactBvh.cpp`) fail to compile with GCC 15. **Use MuJoCo instead** — it ships pre-built wheels and requires no compilation.

```bash
~/project_venv/bin/pip install -i https://pypi.tuna.tsinghua.edu.cn/simple mujoco numpy matplotlib
```

If `pip` is missing: install `build-essential` / `g++` first for any source packages, but MuJoCo itself won't need them.

## Step 2: Real-time viewer (launch_passive)

### Import is mandatory

`mujoco.viewer` is NOT auto-imported by `import mujoco`. You must:

```python
import mujoco
import mujoco.viewer  # REQUIRED even if mujoco is already imported
```

### Wall-clock sync (CRITICAL)

`launch_passive` runs physics at full CPU speed. Without sync, a 15-second sim finishes in ~2 seconds. Always add wall-clock synchronization:

```python
import time

with mujoco.viewer.launch_passive(model, data,
                                   show_left_ui=False,
                                   show_right_ui=False) as viewer:
    step = 0
    dt = model.opt.timestep
    wall_start = time.time()

    while viewer.is_running():
        sim_time = step * dt

        # Real-time sync: don't let sim run ahead of wall clock
        wall_elapsed = time.time() - wall_start
        if sim_time > wall_elapsed:
            time.sleep(sim_time - wall_elapsed)

        # ... control logic ...
        mujoco.mj_step(model, data)

        # Frame skip: sync every N steps (5 steps @ 0.002s = 0.01s ≈ 100fps)
        if step % 5 == 0:
            viewer.sync()
        step += 1
```

### Camera setup

```python
viewer.cam.distance = 1.8      # distance from lookat point
viewer.cam.elevation = -20     # vertical angle (degrees)
viewer.cam.azimuth = 140       # horizontal angle (degrees)
viewer.cam.lookat[:] = [0.4, 0, 0.4]  # point to center on
```

### Overlay text for sensor data

Use `viewer.set_texts()` instead of relying on jittery built-in force arrows:

```python
viewer.set_texts(
    (mujoco.mjtFontScale.mjFONTSCALE_150,
     mujoco.mjtGridPos.mjGRID_TOPLEFT,
     "Force (filtered)",
     f"Fx={fx:+6.2f} N\nFy={fy:+6.2f} N\nFz={fz:+6.2f} N")
)
```

## Step 3: Model creation

MuJoCo uses XML for model definitions. Key elements:

- `<worldbody>` — ground plane, robot body tree, walls/obstacles, lights
- `<actuator>` — motors mapped to joints, with `ctrlrange` for torque limits
- `<sensor>` — `jointpos`, `jointvel`, `force` (at sites)

See `templates/arm_6dof.xml` for a complete 6-DOF arm model (UR5-style: Z-Y-Y-Z-Y-Z axes) with softened contact parameters and force sensor.

## Step 3: Controller patterns

### Joint-space PD control
```python
tau = KP * (q_des - q) - KD * dq
data.ctrl[:] = np.clip(tau, -max_torque, max_torque)
```

### Admittance control (force → motion)
Outer loop: `M * adm_acc + D * adm_vel + K * adm_pos = force`
Integrate to get position correction → IK (numerical Jacobian pseudoinverse) → inner PD.

### Numerical Jacobian
```python
def compute_jacobian(model, data, dq=0.005):
    J = np.zeros((3, model.nv))
    ee0 = data.site("end_effector").xpos.copy()
    q_save = data.qpos.copy()
    for j in range(model.nv):
        data.qpos[j] = q_save[j] + dq
        mujoco.mj_forward(model, data)
        J[:, j] = (data.site("end_effector").xpos - ee0) / dq
        data.qpos[j] = q_save[j]
    mujoco.mj_forward(model, data)
    return J
```

## Pitfalls

### MuJoCo 3.x API changes
- `model.nsens` → `model.nsensor` (renamed in 3.x)
- `model.sensor(i).name` works, but iteration range must use `model.nsensor`
- Default cameras: no "tracking" camera exists unless defined in the model XML. Use `renderer.update_scene(data)` without a camera name for the default view.

### XML schema restrictions (MuJoCo 3.10)
- `<flag>` element can appear only ONCE per parent — combine: `<flag contact="enable" energy="enable"/>`
- `mpr_tolerance` does NOT exist as an `<option>` attribute. Valid ones: `tolerance`, `ls_tolerance`, `noslip_tolerance`.
- `solref` and `solimp` go on `<geom>` elements, not `<option>`.

### Viewer: `import mujoco.viewer` required
`import mujoco` does NOT auto-import the viewer submodule. You must explicitly `import mujoco.viewer`. Forgetting this produces `AttributeError: module 'mujoco' has no attribute 'viewer'`.

### Viewer: wall-clock sync required
`launch_passive` has NO built-in real-time pacing. Without `time.sleep()` sync against a wall clock, the simulation runs at full CPU speed (2s real time for a 15s simulation). See Step 2 for the sync pattern.

### Contact force jittering on screen

**Symptom**: raw contact force arrows (`mjVIS_CONTACTFORCE`) flicker/jump erratically at wall contact.

**Root cause**: MuJoCo's complementarity-based contact solver produces legitimate high-frequency force oscillations in rigid contacts. The arrows faithfully render these — it's not a bug.

**Fix — three parts**:

1. **Disable raw force arrows**, keep contact points only:
```python
viewer.opt.flags[mujoco.mjtVisFlag.mjVIS_CONTACTFORCE] = 0
viewer.opt.flags[mujoco.mjtVisFlag.mjVIS_CONTACTPOINT] = 1
```

2. **Low-pass filter the force sensor** before feeding into the controller:
```python
alpha = 0.1  # smaller = smoother
force_filtered = alpha * raw_force + (1 - alpha) * force_filtered
```

3. **Soften admittance + contact parameters**:
- Increase admittance damping D (60 instead of 25)
- Decrease admittance stiffness K (15 instead of 40)
- Lower inner-loop PD gains (KP 60 instead of 120)
- Add to geom defaults in model XML: `solref="0.02 1" solimp="0.9 0.95 0.001"`

Use `viewer.set_texts()` to display the filtered force as overlay text (see Step 2).

### Contact force oscillation (offline)
Admittance control with naive numerical IK can oscillate at wall contact. Start with M=5, D=60, K=15 for stable demos. Higher D (damping) smooths response; lower K (stiffness) makes the arm "softer" on contact.

## Consolidation note

This skill is the canonical umbrella for all MuJoCo simulation work. It absorbed
`mujoco-robotics-simulation` (2026-07-08 curator pass) which covered the same
WSL setup, viewer patterns, API migration notes, Jacobian, and control loops.

## Verification

After setup, run a quick smoke test:
```python
import mujoco, numpy as np
model = mujoco.MjModel.from_xml_path("arm_6dof.xml")
data = mujoco.MjData(model)
for _ in range(1000):
    mujoco.mj_step(model, data)
print("OK: physics steps, end-effector at", data.site("end_effector").xpos)
```

## Project file structure

```
project/
├── models/          # .xml model files
├── scripts/         # Python demo scripts
├── README.md
└── venv -> ~/project_venv/   # symlink or just documented
```

## References

- `references/wsl-python314-issues.md` — full error transcripts from setup
- `templates/arm_6dof.xml` — reusable 6-DOF arm MJCF model with force sensor
