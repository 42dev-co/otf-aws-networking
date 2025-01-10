package iac.main

import data.compliances
import future.keywords.if
import future.keywords.in

# Aggregate all violations
violations[policy_name] = msgs if {
    some policy_name in object.keys(compliances)
    msgs := [msg | 
        some msg in compliances[policy_name].deny
    ]
    count(msgs) > 0
}
