import os, json

with open(r'd:\Programming projects\agro_shift\docs\fixtures\historical_api\era5_raw.json', 'r', encoding='utf-8-sig') as f:
    fixture = json.load(f)

resp_path = os.path.join(os.environ['TEMP'], 'agroshift_era5_verification', 'era5_api_response.json')
with open(resp_path, 'r', encoding='utf-8-sig') as f:
    fresh = json.load(f)

print('=== METADATA COMPARISON ===')
meta_keys = ['latitude', 'longitude', 'generationtime_ms', 'utc_offset_seconds', 'timezone', 'timezone_abbreviation', 'elevation']
for k in meta_keys:
    f_val = fixture.get(k)
    r_val = fresh.get(k)
    match = (f_val == r_val)
    print(f'{k:<22}: Fixture={f_val!r:<20} | Fresh={r_val!r:<20} | Match={match}')

print('\n=== DAILY UNITS COMPARISON ===')
for k, v in fixture['daily_units'].items():
    r_val = fresh['daily_units'].get(k)
    match = (v == r_val)
    print(f'{k:<26}: Fixture={v!r:<10} | Fresh={r_val!r:<10} | Match={match}')

print('\n=== DAILY ARRAYS COMPARISON ===')
dates = fixture['daily']['time']
assert dates == fresh['daily']['time'], 'Dates mismatch!'

variables = ['temperature_2m_max', 'temperature_2m_min', 'et0_fao_evapotranspiration', 'precipitation_sum']
for var in variables:
    f_vals = fixture['daily'][var]
    r_vals = fresh['daily'][var]
    diffs = [r - f for r, f in zip(r_vals, f_vals)]
    abs_diffs = [abs(d) for d in diffs]
    exact_matches = sum(1 for d in diffs if d == 0.0)
    max_abs_diff = max(abs_diffs)
    mean_abs_diff = sum(abs_diffs) / len(abs_diffs)
    print(f'\nVariable: {var}')
    print(f'  Array Length: Fixture={len(f_vals)}, Fresh={len(r_vals)} (Match={len(f_vals) == len(r_vals)})')
    print(f'  Exact matches: {exact_matches}/{len(f_vals)}')
    print(f'  Max absolute difference: {max_abs_diff:.6f}')
    print(f'  Mean absolute difference: {mean_abs_diff:.6f}')
    print('  Per-day values:')
    for d, fv, rv, diff in zip(dates, f_vals, r_vals, diffs):
        print(f'    {d}: Fixture={fv:<6.2f} | Fresh={rv:<6.2f} | Diff={diff:+.2f}')

print('\n=== NUMERICAL INTEGRITY CHECKS (ET0 & IRRIGATION VOLUME) ===')
f_et0 = fixture['daily']['et0_fao_evapotranspiration']
r_et0 = fresh['daily']['et0_fao_evapotranspiration']

f_total = sum(f_et0)
r_total = sum(r_et0)

conv_factor = 4.2
f_vol = f_total * conv_factor
r_vol = r_total * conv_factor

print(f'Fixture ET0 values: {f_et0}')
print(f'Fixture ET0 Total : {f_total:.4f} mm (Expected target: 38.4900 mm)')
print(f'Fixture Volume    : {f_vol:.4f} m3/feddan (Expected target: 161.6580 m3/feddan)')

print(f'Fresh ET0 values  : {r_et0}')
print(f'Fresh ET0 Total   : {r_total:.4f} mm')
print(f'Fresh Volume      : {r_vol:.4f} m3/feddan')

diff_total = r_total - f_total
diff_vol = r_vol - f_vol
print(f'Total ET0 Difference: {diff_total:+.4f} mm')
print(f'Volume Difference   : {diff_vol:+.4f} m3/feddan')
