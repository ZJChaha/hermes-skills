# WSL + Python 3.14 + MuJoCo Setup — Error Transcript

## Issue 1: pip install timeout on Windows drive (NTFS)

### Symptom
```
/mnt/d/ForceControl_Sim/venv/bin/pip install pybullet matplotlib numpy
[Command timed out after 120s]
```

### Root cause
The venv was on `/mnt/d/` which is a Windows NTFS drive mounted via 9p/WSL. File I/O on NTFS through WSL is 10-50x slower than native ext4. Pip operations that create thousands of small files (wheels, metadata, compiled extensions) hit the 120s timeout.

### Fix
Move venv to WSL native filesystem:
```bash
python3 -m venv ~/ForceControl_Sim_venv   # on ext4, fast
~/ForceControl_Sim_venv/bin/pip install -i https://pypi.tuna.tsinghua.edu.cn/simple mujoco ...
```
Project code can stay on `/mnt/d/` — only the venv needs to be on ext4.

---

## Issue 2: PyBullet C++ compilation failure on Python 3.14

### Symptom
```
error: command 'x86_64-linux-gnu-g++' failed: No such file or directory
  [end of output]
ERROR: Failed building wheel for pybullet
```

After installing g++:
```
src/BulletCollision/Gimpact/btGImpactBvh.cpp:257:31: note: '<anonymous>' declared here
ERROR: Failed building wheel for pybullet
```

### Root cause
Python 3.14 is too new — PyBullet's bundled Bullet Physics C++ source doesn't compile with GCC 15 / Python 3.14 headers. The PyBullet package on PyPI only ships source distributions (no pre-built wheel for cp314).

### Fix
Use MuJoCo instead. MuJoCo (since Google open-sourced it) ships pre-built wheels for all major platforms, including cp314. No C++ compilation needed.
```bash
pip install mujoco numpy matplotlib
```

---

## Issue 3: MuJoCo 3.10 — `nsens` → `nsensor` rename

### Symptom
```
AttributeError: 'mujoco._structs.MjModel' object has no attribute 'nsens'. Did you mean: 'nsensor'?
```

### Fix
Replace all occurrences:
- `model.nsens` → `model.nsensor`
- `range(model.nsens)` → `range(model.nsensor)`

This changed in MuJoCo 3.x (the old name was a typo that was finally corrected).

---

## Issue 4: MuJoCo default camera "tracking" does not exist

### Symptom
```
[WARN] 渲染失败 (无头环境正常): The camera "tracking" does not exist.
```

### Root cause
MuJoCo does NOT ship with a built-in camera named "tracking". This name only works if explicitly defined in the model XML as `<camera name="tracking" mode="tracking"/>`.

### Fix
Either:
1. Omit the camera name: `renderer.update_scene(data)` — uses default view
2. Define the camera in the model XML: `<camera name="tracking" mode="tracking"/>`
