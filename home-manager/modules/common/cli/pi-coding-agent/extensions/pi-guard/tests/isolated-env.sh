# Sourced by test runners: do not borrow forwarding state from the live Pi.
# This only changes the disposable test process, never the interactive parent.
unset PI_SUBAGENT_CHILD PI_SUBAGENT_PARENT_SESSION PI_SUBAGENT_PI_BINARY
unset PI_AGENT_ROUTER_PARENT_SESSION_ID
unset PI_PERMISSION_FORWARDING_ROOT_SESSION PI_PERMISSION_FORWARDING_NODE
unset PI_PERMISSION_FORWARDING_CLI PI_PERMISSION_FORWARDING_DELEGATE_PI_BINARY
