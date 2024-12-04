module Optimization

using JuMP, Gurobi

export build_dcopf, solve_model


"""
    build_dcopf(data::Dict)

Builds and returns a DC Optimal Power Flow (DCOPF) model using the input `data`.
"""
function build_dcopf(data::Dict)
    # JuMP model with the Gurobi solver
    model = Model(Gurobi.Optimizer)

    # Extract data
    bus = data[:bus]            # Bus data
    branch = data[:branch]      # Transmission lines
    plant = data[:plant]        # Generator data
    load = data[:load]          # Load data
    gencost = data[:gencost]    # Generator cost

    # Decision variables
    @variable(model, θ[bus[:id]], start=0)  # Voltage angles
    @variable(model, p[plant[:id]] >= 0)    # Generator outputs

    # Objective: Minimize generation costs
    @objective(model, Min, sum(gencost[i, :cost] * p[i] for i in plant[:id]))

    # Power balance constraints at each bus
    for i in bus[:id]
        @constraint(
            model,
            sum(p[j] for j in plant[:id] if plant[j, :bus] == i) -
            sum(load[j, :demand] for j in load[:id] if load[j, :bus] == i) ==
            sum(branch[k, :flow] for k in branch[:id] if branch[k, :to] == i) -
            sum(branch[k, :flow] for k in branch[:id] if branch[k, :from] == i)
        )
    end

    # Flow limits on transmission lines
    for k in branch[:id]
        @constraint(model, -branch[k, :limit] <= branch[k, :flow] <= branch[k, :limit])
    end

    return model
end


"""
    solve_model(model::Model)

Solves the optimization model and returns the results.
"""
function solve_model(model::Model)
    optimize!(model)

    if termination_status(model) == MOI.OPTIMAL
        println("Optimal solution found.")
        return value.(model)
    else
        println("No optimal solution.")
        return nothing
    end
end

end