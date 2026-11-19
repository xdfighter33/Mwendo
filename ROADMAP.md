# Mwendo Roadmap

*Mwendo* (Swahili: "motion") is a physics engine.

| Milestone | Status |
|---|---|
| Engine core | ✅ Done |
| Renderer | ✅ Done |
| **PBD Implementation** | 🔲 In progress — issue #1 |

---

## 🔲 PBD Implementation

Follows **Müller, Heidelberger, Hennix & Ratcliff, "Position Based Dynamics" (2007)**.
Each task maps to a line of **Algorithm 1** and the section that defines it.
Notation: `x` position, `v` velocity, `p` predicted position, `w = 1/m` inverse mass, `Δt` timestep.

### The one idea
> Don't integrate forces into positions. **Guess** where particles go (`p`), **fix** the guess
> until constraints are satisfied, then **derive** velocity from how far they actually moved.

---

### Phase A — Setup (Algorithm 1, line 1)

- [ ] **A1. Particle state** — §3.1
  `xᵢ = xᵢ⁰`, `vᵢ = vᵢ⁰`, `wᵢ = 1/mᵢ`
- [ ] **A2. Attachments** — §3.6
  Pin a particle by setting `wᵢ = 0` (infinite mass, never moves)

### Phase B — Predict (lines 4–6) *"guess"*

- [ ] **B1. External forces** — line 4
  `vᵢ ← vᵢ + Δt · wᵢ · f_ext(xᵢ)`
- [ ] **B2. Damping** — line 5, §3.5
  `x_cm = Σ xᵢmᵢ / Σ mᵢ`, `v_cm = Σ vᵢmᵢ / Σ mᵢ`
  `L = Σ rᵢ × (mᵢvᵢ)`, `I = Σ r̃ᵢ r̃ᵢᵀ mᵢ`, `ω = I⁻¹L`
  `Δvᵢ = v_cm + ω × rᵢ − vᵢ`, `vᵢ ← vᵢ + k_damping · Δvᵢ`
  *(damps wobble without slowing rigid motion)*
- [ ] **B3. Predict positions** — line 6
  `pᵢ ← xᵢ + Δt · vᵢ`

### Phase C — Correct (lines 7–10) *"fix the guess"*

- [ ] **C1. Collision constraints** — line 7, §3.4
  Ray-cast `xᵢ → pᵢ`; on hit at `q_c` with normal `n_c`:
  `C(p) = (p − q_c) · n_c ≥ 0`
- [ ] **C2. Constraint interface** — §3.2
  Each constraint `Cⱼ` has: cardinality `nⱼ`, function `Cⱼ(p)`, gradient `∇Cⱼ`, stiffness `kⱼ`, type (`= 0` or `≥ 0`)
- [ ] **C3. General projection** — §3.3
  `s = C(p) / Σⱼ wⱼ |∇_{pⱼ}C(p)|²`
  `Δpᵢ = −s · wᵢ · ∇_{pᵢ}C(p)`
- [ ] **C4. Stiffness** — §3.3
  `k' = 1 − (1 − k)^(1/n_s)`  *(so stiffness doesn't depend on iteration count `n_s`)*
- [ ] **C5. Gauss–Seidel solver loop** — lines 8–10
  `loop solverIterations: projectConstraints(C₁…C_{M+M_coll}, p₁…p_N)`

### Phase D — Update (lines 11–14) *"derive velocity"*

- [ ] **D1. Velocity from positions** — line 12
  `vᵢ ← (pᵢ − xᵢ) / Δt`
- [ ] **D2. Commit positions** — line 13
  `xᵢ ← pᵢ`
- [ ] **D3. Friction & restitution** — line 14, §3.4
  `velocityUpdate(v₁…v_N)` for colliding particles

---

### Phase E — Constraint library (§3.3, §4)

- [ ] **E1. Distance (stretch)** — §3.3, §4.1
  `C(p₁,p₂) = |p₁ − p₂| − d`
  `Δp₁ = −(w₁/(w₁+w₂)) (|p₁−p₂| − d) (p₁−p₂)/|p₁−p₂|`
  `Δp₂ = +(w₂/(w₁+w₂)) (|p₁−p₂| − d) (p₁−p₂)/|p₁−p₂|`
- [ ] **E2. Bending** — §4.1
  `C(p₁,p₂,p₃,p₄) = acos(n₁ · n₂) − φ₀`
- [ ] **E3. Self-collision** — §4.3
  `C(q,p₁,p₂,p₃) = (q − p₁) · n − h`
- [ ] **E4. Pressure / balloon** — §4.4
  `C(p₁…p_N) = Σ (p_{t₁} × p_{t₂}) · p_{t₃} − k_pressure · V₀`

### Phase F — Hook into Mwendo

- [ ] **F1.** Call the PBD step from the engine's update loop
- [ ] **F2.** Send `xᵢ` to the renderer each frame

### Phase G — Demos (paper §5)

- [ ] **G1.** Rope / pendulum chain (A + B + C + D + E1)
- [ ] **G2.** Hanging cloth (+ E2)
- [ ] **G3.** Cloth with self-collision (+ E3)
- [ ] **G4.** Inflated balloon (+ E4)

### Later — XPBD (Macklin et al., 2016)
- [ ] Compliance `α̃ = α/Δt²`, Lagrange multiplier `λ`: `Δλ = (−C − α̃λ) / (Σ wᵢ|∇Cᵢ|² + α̃)`
