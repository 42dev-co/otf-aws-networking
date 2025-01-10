package budget

import future.keywords.if
import future.keywords.in

# Set the maximum allowed monthly budget
max_monthly_budget = 120.0

# Deny if the total monthly cost exceeds the budget
deny contains msg if {
    monthly_cost := to_number(input.totalMonthlyCost)
    monthly_cost > max_monthly_budget
    msg := sprintf("Total monthly cost of $%.2f exceeds the maximum budget of $%.2f", [monthly_cost, max_monthly_budget])
}
