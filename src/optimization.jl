# TODO: 
# - Update the DCOPF to smt closer to Notebook version
# - write the stochastic version using train_data generated by generate_batches()
# - Find heuristic methods
# - Implement the heuristic methods


module Optimization

using JuMP, HiGHS

export build_dcopf, solve_model


"""
    build_dcopf(data::Dict)

Builds and returns a DC Optimal Power Flow (DCOPF) model using the input `data`.
"""
function build_dcopf(data::Dict)
    bus = data["bus"]
    branch = data["branch"]
    plant = data["plant"]
    load = data["load"]
    gencost = data["gencost"]

    bus_id_map = Dict(sort(unique(bus.bus_id)) .=> 1:length(unique(bus.bus_id)))

    # Define sets
    G = sort(unique(plant.idx))         # Set of generator buses (indices)
    D = 1:(ncol(load)-2)                # Set of demand nodes 
    N = sort(unique(bus.idx))           # Set of all buses (indices)
    L = sort(unique(branch.branch_id))  # Set of branches (indices)
    T = 1:length(load.time)

    # Per unit base
    baseMVA = 100

    # Create the DCOPF model
    DCOPF = Model(HiGHS.Optimizer)

    # Define decision variables
    @variables(DCOPF, begin
        GEN[G, T]                          # Generator output (assume Pmin = 0)
        THETA[N, T]                        # Voltage phase angle at each bus
        FLOW[L, T]                         # Power flow on each branch
    end)

    # Slack bus constraint: fix reference angle at the first bus
    slack_bus = N[1]
    fix(THETA[slack_bus], 0)

    # Objective function: minimize generation cost
    @objective(DCOPF, Min, 
        sum(
            gencost[gencost.plant_id .== g, :c2][1] * GEN[g]^2 +
            gencost[gencost.plant_id .== g, :c1][1] * GEN[g] +
            gencost[gencost.plant_id .== g, :c0][1] 
            for g in G
        )
    )
    
    # WIP ---- Power balance constraint at each bus
    @constraint(DCOPF, cBalance[n in N], 
        sum(GEN[g] for g in G if plant.idx[g] == n) +                               # Generation at bus n
        sum(load[Symbol(string(n))] for n in names(load) if parse(Int, n) == n) ==  # Load at bus n
        sum(FLOW[l] for l in L if branch.start_idx[l] == n) -                       # Outgoing flows
        sum(FLOW[l] for l in L if branch.end_idx[l] == n)                           # Incoming flows
    )

    # Maximum generation constraint for each generator
    @constraint(DCOPF, cMaxGen[g in G], 
        GEN[g] <= plant[plant.idx .== g, :pgmax][1]
    )

    # OK ---- Generator limit constraints
    @constraint(DCOPF, cMinGen[g in G, t in T], GEN[g,t] >= plant[plant.idx .== g, :pmin][1])
    @constraint(DCOPF, cMaxGen[g in G, t in T], GEN[g,t] <= plant[plant.idx .== g, :pmax][1])
    
    # OK ---- Ramping constraints (divide by 2 for hourly ramp)
    @constraint(DCOPF, ramp_up[g in G, t in 2:T], P[g,t] - P[g,t-1] <= plant[plant.idx .== g, :ramp_30][1] / 2)
    @constraint(DCOPF, ramp_down[g in G, t in 2:T], P[g,t-1] - P[g,t] <= plant[plant.idx .== g, :ramp_30][1] / 2)

    # Line flow constraints based on susceptance
    @constraint(DCOPF, cLineFlows[l in L], 
        FLOW[l] == baseMVA * branch.sus[l] * 
                   (THETA[branch.start_idx[l]] - THETA[branch.end_idx[l]])
    )

    # Maximum line flow constraints
    @constraint(DCOPF, cLineLimits[l in L], 
        abs(FLOW[l]) <= branch.capacity[l]
    )

    return DCOPF
end


"""
    build_stochastic_dcopf(data::Dict, scenarios::Vector{Dict}, probs::Vector{Float64})

Builds and returns a stochastic DC Optimal Power Flow (DCOPF) model using the input `data`, a set of `scenarios`,
and their associated probabilities `probs`.
"""
function build_stochastic_dcopf(data::Dict, scenarios::Vector{Dict}, probs::Vector{Float64})
    # Validate input
    @assert length(scenarios) == length(probs) "Each scenario must have an associated probability."
    @assert sum(probs) ≈ 1.0 "Probabilities must sum to 1."

    # Extract common data
    bus = data["bus"]
    plant = data["plant"]
    gencost = data["gencost"]

    # Define sets
    G = plant.id                 # Generator IDs
    N = bus.bus_i                # Bus (node) IDs
    S = 1:length(scenarios)      # Scenario indices

    # Base MVA value
    baseMVA = 100.0

    # Create the optimization model
    StochDCOPF = Model(HiGHS.Optimizer)

    # Define scenario-specific variables and constraints
    @variables(StochDCOPF, begin
        GEN[g in G, s in S] >= 0  # Generator outputs per scenario
        THETA[n in N, s in S]    # Voltage angle at each bus per scenario
    end)

    # Fix reference bus angle to 0 for all scenarios
    for s in S
        fix(THETA[1, s], 0)
    end

    # Objective function: Minimize expected generation costs across scenarios
    @objective(StochDCOPF, Min,
        sum(probs[s] * sum(gencost[g, :x1] * GEN[g, s] for g in G) for s in S)
    )

    # Add scenario-specific constraints
    for s in S
        scenario = scenarios[s]
        scenario_branch = scenario["branch"]
        scenario_load = scenario["load"]

        # Power balance constraints
        @constraint(StochDCOPF, [i in N],
            sum(GEN[g, s] for g in plant[plant.bus .== i, :id]) - 
            sum(scenario_load[scenario_load.bus .== i, :demand]) == 
            sum(scenario_branch[scenario_branch.fbus .== i, :sus] .* 
                (THETA[i, s] - THETA[scenario_branch[scenario_branch.fbus .== i, :tbus]]))
        )

        # Generation capacity constraints
        @constraint(StochDCOPF, [g in G], GEN[g, s] <= plant[plant.id .== g, :pmax][1])

        # Line flow constraints
        @constraint(StochDCOPF, [k in 1:size(scenario_branch, 1)],
            scenario_branch[k, :sus] * baseMVA * 
            (THETA[scenario_branch[k, :fbus], s] - THETA[scenario_branch[k, :tbus], s]) <= scenario_branch[k, :ratea]
        )
    end

    return StochDCOPF
end



"""
    solve_model(model::Model)

Solves the optimization model and returns the results as a named tuple with:
    - generation: DataFrame of generator outputs
    - angles: Vector of voltage angles
    - flows: DataFrame of transmission line flows
    - prices: DataFrame of marginal prices at each bus
    - cost: Optimal generation cost
    - status: Solver termination status
"""
function solve_model(DCOPF::Model, data::Dict)
    bus = data["bus"]
    branch = data["branch"]
    plant = data["plant"]

    N = sort(unique(bus.bus_id))

    # Solve the model
    optimize!(DCOPF)

    # Output results
    generation = DataFrame(
        bus = plant.bus_id,
        generation = value.(GEN)
    )

    angles = value.(THETA)

    flows = DataFrame(
        from_bus = branch.start_bus,
        to_bus = branch.end_bus,
        flow = [value(FLOW[f, t]) for (f, t) in zip(branch.start_bus, branch.end_bus)]
    )

    prices = DataFrame(
        bus = N,
        price = dual.(cBalance)
    )

    return (
        generation = generation,
        angles = angles,
        flows = flows,
        prices = prices,
        cost = objective_value(DCOPF),
        status = termination_status(DCOPF)
    )
end


end
