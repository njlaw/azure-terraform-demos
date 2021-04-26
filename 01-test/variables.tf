variable "agent_count" {
    default = 2
}

variable "ssh_public_key" {
    default = "~/.ssh/njlaw-03.pub"
}

variable log_analytics_workspace_name {
    default = "testLogAnalyticsWorkspaceName"
}

variable log_analytics_workspace_sku {
    default = "PerGB2018"
}
