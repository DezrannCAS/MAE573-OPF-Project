using CSV, DataFrames

data_dir = "/home/esteban_nb/dirhw/mae573-term-project/data"
clean_data_dir = joinpath(data_dir, "newdata")

println("Loading data from $data_dir...")
bus = CSV.read(joinpath(data_dir, "bus.csv"), DataFrame)
branch = CSV.read(joinpath(data_dir, "branch.csv"), DataFrame)
plant = CSV.read(joinpath(data_dir, "plant.csv"), DataFrame)
load = CSV.read(joinpath(data_dir, "load.csv"), DataFrame)
gencost = CSV.read(joinpath(data_dir, "gencost.csv"), DataFrame)


# Rename columns
for f in [plant, gencost, branch, bus]
    rename!(f,lowercase.(names(f)))
end
rename!(branch, :from_bus_agg => :start_bus, :to_bus_agg => :end_bus)
rename!(bus, :bus_agg => :bus_id)
rename!(plant, :bus_agg => :bus_id)

# Add new identifiers (idx always refers to a bus index ranging from 1 to N)
bus_id_map = Dict(sort(unique(bus.bus_id)) .=> 1:length(unique(bus.bus_id)))
bus[!, :idx] = [bus_id_map[id] for id in bus.bus_id]
plant[!, :bus_idx] = [bus_id_map[id] for id in plant.bus_id]
branch[!, :start_idx] = [bus_id_map[id] for id in branch.start_bus]
branch[!, :end_idx] = [bus_id_map[id] for id in branch.end_bus]
    
# Overwrite plant and branch IDs
plant_id_map = Dict(plant.plant_id .=> 1:nrow(plant))
plant.plant_id = 1:nrow(plant)
gencost[!, :plant_id] = [plant_id_map[id] for id in gencost.plant_id]
branch.branch_id = 1:nrow(branch)

# Aggregate all branches together 
aggregated_branch = combine(groupby(branch[:, [:start_idx, :end_idx, :x, :ratea]], [:start_idx, :end_idx]),
    :x => (x -> 1 / sum(1 ./ x)) => :x,
    :ratea => sum => :ratea
)


CSV.write(joinpath(clean_data_dir, "bus.csv"), bus)
CSV.write(joinpath(clean_data_dir, "branch.csv"), aggregated_branch)
CSV.write(joinpath(clean_data_dir, "plant.csv"), plant)
CSV.write(joinpath(clean_data_dir, "load.csv"), load)
CSV.write(joinpath(clean_data_dir, "gencost.csv"), gencost)

