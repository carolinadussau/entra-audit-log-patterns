# Entra ID Audit Log Patterns – Group Membership Changes

## Context
This repository contains reference patterns for analyzing Entra ID AuditLogs
in Azure Log Analytics, with a focus on tracking access changes for groups.

The goal is to reliably identify:
- which access-change action occurred
- who performed the action
- which group was affected
- which users or principals were added or removed

All identifiers in this repository are synthetic placeholders.
No customer, employer, or tenant data is included.

## Problem
An initial AI-generated approach attempted to extract added or removed users
from the `modifiedProperties` field of the AuditLogs table.

While this works for some metadata, it does not reliably return the affected
user accounts for group membership changes.

## Investigation
By inspecting the Entra ID audit schema, I confirmed that membership changes
are often represented as separate entries inside the `TargetResources` array,
rather than as deltas embedded in `modifiedProperties`.

This means that a query must correlate multiple TargetResources per audit event
to correctly identify both the group and the affected principals.

## Correction
The final query preserves the original filtering logic but extracts affected
users and service principals directly from `TargetResources`.

This approach aligns with how Entra ID emits group membership changes and
produces consistent results when the data is available.

## Constraints and Limitations
- Audit log retention depends on tenant configuration and licensing
- Not all audit events populate userPrincipalName; objectId may be the only identifier
- Microsoft Graph directory audit endpoints may expose a shorter retention window
  than logs streamed to Log Analytics
- This repository intentionally focuses on reasoning patterns and failure modes rather than exhaustive automation.

These constraints are documented intentionally rather than abstracted away.

## Outcome
The result is a reusable and defensible query pattern suitable for audit and
compliance scenarios, along with a documented understanding of platform limits
and failure modes.
