# AgroShift — Agricultural Methods and Scientific Evidence Dossier

**Document Version:** 1.0.0  
**Target Region:** Nile Delta (Lower Egypt) & Nile Valley (Middle/Upper Egypt)  
**Governing Standard:** FAO Irrigation and Drainage Paper No. 56 / ARC Egypt Technical Bulletins

---

## 1. Non-Guarantee and Evidentiary Boundaries

> **Mandatory Scientific Statement:**  
> AgroShift is an educational, analytical, and scenario-comparison decision-support tool. **It does NOT guarantee crop yields, water savings, market returns, or biological outcomes.** All calculations represent physical and physiological estimates based on gridded atmospheric models and published agronomic coefficients. When field-level soil tests or in-situ station data are missing, models provide indicative bounds, not deterministic predictions.

---

## 2. Approved Agronomic Formulas

### 2.1 Reference Evapotranspiration ($ET_0$) — FAO-56 Penman-Monteith
Reference evapotranspiration represents the rate of evapotranspiration from an extensive surface of 0.12 m tall green grass cover of uniform height, actively growing, completely shading the ground and with adequate water:

$$ET_0 = \frac{0.408 \Delta (R_n - G) + \gamma \frac{900}{T + 273} u_2 (e_s - e_a)}{\Delta + \gamma (1 + 0.34 u_2)}$$

- **Unit:** $\text{mm/day}$
- **Source:** Allen, R. G., Pereira, L. S., Raes, D., & Smith, M. (1998). *Crop evapotranspiration-Guidelines for computing crop water requirements-FAO Irrigation and drainage paper 56*. FAO, Rome.
- **Provider Implementation:** Open-Meteo pre-calculates daily $ET_{0,\text{FAO}}$ using the standard Penman-Monteith formulation driven by hourly solar radiation, 2m temperature, 2m dew point, and 10m wind speed.

### 2.2 Crop Evapotranspiration & Water Requirement ($ET_c$)
The water requirement for an unconstrained crop is calculated via single-crop coefficient:

$$ET_c = K_c \times ET_0$$

- **Unit:** $\text{mm/day}$
- **Volumetric Conversion for Egyptian Agriculture:**
  $$1\text{ mm} = 10\text{ m}^3 / \text{hectare} = 4.2\text{ m}^3 / \text{feddan}$$
  Therefore, volumetric irrigation demand per feddan over a period of $N$ days is:
  $$V_{\text{water}} (\text{m}^3/\text{feddan}) = 4.2 \times \sum_{d=1}^N (K_c(d) \times ET_{0}(d))$$

### 2.3 Growing Degree Days ($\text{GDD}$)
Accumulated thermal time driving phenological crop development:

$$\text{GDD} = \max\left(0, \frac{T_{\max} + T_{\min}}{2} - T_{\text{base}}\right)$$

If $T_{\max} > T_{\text{cutoff}}$, then $T_{\max}$ is capped at $T_{\text{cutoff}}$ for crops susceptible to severe physiological dormancy under extreme heat (e.g., maize: $T_{\text{base}} = 10^\circ C, T_{\text{cutoff}} = 30^\circ C$).

### 2.4 Heat Stress Risk Index ($\text{HSRI}$)
Quantifies exposure to critical thermal thresholds during sensitive reproductive or grain-filling stages:
$$\text{Days with } T_{\max} \ge T_{\text{critical}}$$
- **Wheat (flowering/grain fill):** $T_{\text{critical}} = 31^\circ C$
- **Maize (silking/tasseling):** $T_{\text{critical}} = 35^\circ C$
- **Cotton (boll development):** $T_{\text{critical}} = 38^\circ C$

---

## 3. Egyptian Benchmark Crop Profiles & Coefficients ($K_c$)

Values derived from FAO-56 Table 12 and Egyptian Agricultural Research Center (ARC) localized recommendations for the Nile Delta:

| Crop (محصول) | Season (الموسم) | $T_{\text{base}}$ (°C) | $T_{\text{critical}}$ (°C) | $K_{c,\text{ini}}$ | $K_{c,\text{mid}}$ | $K_{c,\text{end}}$ | Typical Duration | Soil Impact |
|---|---|---|---|---|---|---|---|---|
| **Wheat (قمح)** | Winter (شتوي) | 5.0 | 31.0 | 0.40 | 1.15 | 0.35 | 150 days | Nutrient depleting (N/P) |
| **Egyptian Clover / Berseem (برسيم)** | Winter (شتوي) | 6.0 | 32.0 | 0.45 | 1.05 | 0.90 | 160 days (multi-cut) | **N-Fixing / Soil Enriching** |
| **Faba Bean (فول بلدي)** | Winter (شتوي) | 4.0 | 30.0 | 0.50 | 1.15 | 0.30 | 140 days | **N-Fixing / Soil Enriching** |
| **Maize (ذرة شامية)** | Summer (صيفي) | 10.0 | 35.0 | 0.30 | 1.20 | 0.60 | 120 days | Heavy N/Water consumer |
| **Rice (أرز)** | Summer (صيفي) | 12.0 | 36.0 | 1.05 | 1.20 | 0.90 | 135 days | Extremely high water demand |
| **Cotton (قطن)** | Summer (صيفي) | 14.0 | 38.0 | 0.35 | 1.20 | 0.65 | 180 days | Moderate water / High heat tolerance |

---

## 4. Multi-Season Crop-Rotation Evaluation Rules

AgroShift evaluates crop sequences across 3 scientific dimensions:

1. **Cumulative Water Consumption ($m^3/\text{feddan}$):**
   $$\sum_{\text{cycle}} V_{\text{water}}$$
   Enables direct comparison between traditional heavy rotations (e.g. Berseem $\to$ Rice) versus water-conserving alternatives (e.g. Faba Bean $\to$ Maize or Wheat $\to$ Cotton).

2. **Soil Nitrogen & Biological Succession Balance:**
   - **Legume preceding Cereal (e.g. Berseem $\to$ Maize):** Evaluated as **Synergistic (+1)**. Legume biological nitrogen fixation reduces chemical fertilizer reliance and improves soil organic matter.
   - **Cereal preceding Cereal (e.g. Wheat $\to$ Maize):** Evaluated as **Depleting (-1)**. Increases soil exhaustion and disease carryover risk.

3. **Phenological Window Fit (Turnaround Time):**
   - The gap between harvest of Winter crop and sowing of Summer crop must be $\ge 14\text{ days}$ for seedbed preparation. If negative or $<7\text{ days}$, flagged with a **Schedule Conflict Warning**.

---

## 5. Explicitly Unapproved Methods (Excluded from Decision Logic)

The following methods lack sufficient localized validation data or rely on speculative heuristics and are **EXPLICITLY REJECTED**:
- **Black-box Yield Prediction:** (e.g., claiming a specific rotation will yield $24\text{ ardab/feddan}$).
- **Monetary / Profit Predictions:** (e.g., estimating profit in EGP, which depends on volatile market prices, currency fluctuations, and input subsidies).
- **Satellite Spectral Index Yield Regression:** (e.g., mapping single-date NDVI directly to yield without ground calibration).
- **Arbitrary Scoring Formulas:** (e.g., combining unrelated variables into a single unscientific "Suitability Score %").
