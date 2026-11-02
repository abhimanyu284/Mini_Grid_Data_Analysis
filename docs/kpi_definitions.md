# Solar Generation & Smart-Meter Analytics: KPI Definitions

## 1. Problem statement
Two real datasets feed one analytics pipeline. On the supply side, 44
inverters across two solar plants in India: which ones underperform, and
how available are they? On the demand side, about 500 London households
in 2013: when and how do they use electricity, and do time-of-use
customers behave differently from standard-tariff customers?
The two datasets are independent and are never joined.

## 2. Data
| Source | Grain | Period |
|---|---|---|
| Solar generation + weather sensors (2 plants, 22 inverters each) | 15 min | 34 days |
| London smart meters (first 10 blocks, ~500 households) | 30 min | 2013 only |
| London weather (hourly, daily), bank holidays | hourly / daily | 2011-2014 |

## 3. Module A: Solar generation KPIs
| KPI | Formula | Grain |
|---|---|---|
| Inverter availability % | Intervals with AC > 0 during daylight / expected daylight intervals x 100 (daylight = irradiation > 0.1) | Inverter-day |
| Energy yield (kWh) | Sum of AC power (kW) x 0.25 h | Inverter-day |
| Yield per unit sunlight | Energy yield / sum of irradiation x 0.25 | Inverter-day |
| Relative performance | Yield per unit sunlight / plant median that day | Inverter-day, median over period |
| DC-to-AC efficiency | Sum AC / sum DC where DC > 0 (only if units check out) | Plant, inverter |
| Plant daily energy | Sum of inverter yields | Plant-day |

## 4. Module B: Smart-meter KPIs
| KPI | Formula | Grain |
|---|---|---|
| Daily consumption | Sum of 48 half-hour readings (kWh) | Household-day |
| Evening-peak share | kWh 17:00-20:00 / daily kWh | Household-day |
| Night baseload | Mean kWh per half hour, 00:00-05:00 | Household-day |
| Load factor | Mean half-hour kWh / max half-hour kWh | Household-month |
| Peak half-hour demand | Max half-hour kWh | Household-month |
| Billed amount (assumption) | Daily kWh x 14.228p flat rate | Household-day |
| Weather sensitivity | Correlation of daily kWh with daily mean temperature | Tariff group, Acorn group |
| Anomaly flag | Zero or sharply dropped consumption days | Household-day |

Comparisons: Std vs ToU, and across Acorn groups.

## 5. Assumptions and limits
- Solar data covers 34 days only, so there is no seasonal analysis.
- London data is not rural India; the modules stay separate.
- Missing generation rows count as unavailable.
- Billing uses a flat rate unless the ToU schedule is added.