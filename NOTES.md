1. player disconnects while in beltlayer view
2. player takes damage while in beltlayer view
3. player is killed while in beltlayer view

# TODO

1. support multiple surfaces
2. ghost handling

# to test

1. placing surface when underground is obstructed
2. spill to surface when inventory is full and removing ghost with pipes in chest

# blueprints

(DONE) creating a blueprint with a connector also blueprints underground pipes within the region
(DONE) placing blueprint places ghosts underground
(DONE) invisible chest with item requests on 1st connector aboveground
if connector or connector ghost is mined, give items to player / spill to player location / set deconstruct order on invisible chest
if connector or connector ghost is destroyed, destroy chest and its contents
(DONE) on tick, use pipes in chest to revive underground ghosts
(DONE) when all ghosts revived, destroy chest if empty, mark for deconstruction otherwise

(DONE) if item request proxy is mined, put any contents to player, or destroy destroy chest if empty, mark for deconstruction otherwise

# deconstruction

when connector is marked for deconstruction, mark underground pipes in same area for deconstruction
when connector is actually mined, destroy underground pipes and put them in a chest marked for deconstruction
if connector deconstruction is cancelled, cancel underground pipe deconstruction