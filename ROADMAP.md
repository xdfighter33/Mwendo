# Mwendo Roadmap

*Mwendo* (Swahili: "motion") is a physics engine.

## Status

| Milestone | Status |
|---|---|
| Engine core | ✅ Done |
| Renderer | ✅ Done |
| **PBD Implementation** | 🔲 In progress — [action item](../../issues) |

## ✅ Engine core
- [x] Core engine architecture

## ✅ Renderer
- [x] Rendering pipeline

## 🔲 PBD Implementation

Position Based Dynamics (Müller et al., 2007).

### 1. Particle state
- [ ] Position `x`, velocity `v`, inverse mass `w` (w = 0 for pinned)
- [ ] Predicted position buffer `p`

### 2. Prediction step
- [ ] Apply external forces: `v += dt * w * f_ext`
- [ ] Velocity damping
- [ ] Predict: `p = x + dt * v`

### 3. Constraint framework
- [ ] Constraint interface: `C(p)`, `∇C`, stiffness `k`
- [ ] Gauss–Seidel solver loop with configurable iteration count
- [ ] Projection: `Δp_i = -s · w_i · ∇C_i`, with `s = C / Σ w_j |∇C_j|²`

### 4. Constraints
- [ ] Distance (ropes, cloth edges)
- [ ] Static collision (ground plane, boxes)
- [ ] Particle–particle collision
- [ ] Bending (cloth)
- [ ] Volume / shape matching (soft bodies)

### 5. Integration
- [ ] Velocity update: `v = (p - x) / dt`, then `x = p`
- [ ] Substepping
- [ ] XPBD compliance (`α`, `λ`) for timestep-independent stiffness

### 6. Integration with the existing engine
- [ ] Hook PBD step into the engine's update loop
- [ ] Feed particle positions to the renderer

### 7. Demos and validation
- [ ] Rope / pendulum chain
- [ ] Hanging cloth
- [ ] Soft body drop
- [ ] Energy / stability tests and benchmark
