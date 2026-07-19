# 🚗 BSRP PDM

A modern vehicle dealership system built exclusively for the **BSRP Framework**.

BSRP PDM provides a complete player dealership experience, allowing players to browse, purchase, and manage vehicles while integrating directly with the BSRP ecosystem. Designed for performance, flexibility, and immersive roleplay, it serves as the foundation for vehicle sales and dealership operations across BSRP resources.

---

## Features

* 🚗 Vehicle showroom system
* 🏢 Player dealership experience
* 🔍 Vehicle browsing
* 💰 Vehicle purchasing
* 📄 Purchase validation
* 🔑 Vehicle ownership integration
* 🚘 Test drive support
* 📦 Vehicle stock management
* ⚡ Optimized performance
* 🔗 Full BSRP Framework integration

---

## Framework Requirements

This resource requires:

* BSRP Framework
* oxmysql
* ox_lib

Recommended:

* ox_inventory
* bsrp-characters
* bsrp-garages
* bsrp-vehicles
* bsrp-banking

---

## Installation

### 1. Place Resource

```text
resources/
└── bsrp-pdm/
```

### 2. Ensure Dependencies

```cfg
ensure oxmysql
ensure ox_lib
ensure bsrp

ensure bsrp-pdm
```

> BSRP PDM must start after the `bsrp` core resource.

---

## Database

Import the provided SQL file if included:

```sql
sql/bsrp-pdm.sql
```

If automatic database initialization is enabled, required tables will be created automatically.

---

## Configuration

Configuration options can be found in:

```text
config.lua
```

Available settings may include:

* Dealership locations
* Vehicle categories
* Vehicle prices
* Test drive settings
* Payment methods
* Sales permissions
* Display settings

---

## Dealership System

### Vehicle Browsing

Players can:

* View available vehicles
* Browse dealership inventory
* Preview vehicle information
* Compare available options

### Vehicle Purchasing

Players can:

* Purchase vehicles
* Complete payment transactions
* Receive vehicle ownership
* Register purchased vehicles

### Test Drives

Players can:

* Test available vehicles
* Experience vehicles before purchase
* Return vehicles after testing

---

## Vehicle Data

Each vehicle stores:

* Vehicle Model
* Vehicle Price
* Vehicle Class
* Ownership Information
* Plate Information
* Vehicle Status
* Purchase Records

---

## Framework Integration

### Get Player

```lua
local player = exports.bsrp:GetPlayer(source)

if player then
    print(player.PlayerData.citizenid)
end
```

### Create Vehicle Ownership

```lua
local citizenid = player.PlayerData.citizenid

-- Vehicle ownership logic
```

### Check Character Loaded

```lua
if player and player.loaded then
    -- Player character is active
end
```

---

## PDM Events

Example usage:

```lua
RegisterNetEvent('bsrp:pdmVehiclePurchased', function(vehicle)
    print('Vehicle purchased:', vehicle)
end)
```

```lua
RegisterNetEvent('bsrp:pdmTestDriveStarted', function()
    print('Test drive started.')
end)
```

> Event names may vary depending on implementation.

---

## Permissions

Administrative dealership actions can utilize the BSRP permission system:

```lua
if exports.bsrp:IsAdmin(source, 2) then
    -- Dealership administration actions
end
```

---

## Compatibility

| Resource          | Supported |
| ----------------- | --------- |
| BSRP Framework    | ✅         |
| oxmysql           | ✅         |
| ox_lib            | ✅         |
| ox_inventory      | ✅         |
| bsrp-characters   | ✅         |
| bsrp-garages      | ✅         |
| bsrp-banking      | ✅         |

---

## Vehicle Lifecycle

### Player Opens Dealership

1. Player enters dealership
2. Vehicle inventory loads
3. Available vehicles are displayed
4. Player selects a vehicle

### Vehicle Purchase

1. Player confirms purchase
2. Payment is validated
3. Vehicle ownership is created
4. Vehicle information is saved

### Vehicle Storage

Vehicle data is automatically saved during:

* Purchase completion
* Ownership updates
* Server restart
* Database synchronization

---

## Development

When creating resources that depend on vehicle ownership:

```lua
local player = exports.bsrp:GetPlayer(source)

if not player then
    return
end

local citizenid = player.PlayerData.citizenid
```

Always verify ownership and player data server-side before processing vehicle transactions.
