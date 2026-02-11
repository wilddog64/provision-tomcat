# Project Brief: provision-tomcat

## Purpose
`provision-tomcat` is an Ansible role repository focused on installing, upgrading, and operating Apache Tomcat on Windows hosts. It is designed for repeatable infrastructure automation across local Vagrant/Test Kitchen workflows and Azure-based sandbox validation.

## Core Outcomes
- Install Tomcat from official Apache ZIP artifacts (no Chocolatey dependency for Tomcat itself).
- Manage Windows service lifecycle for Tomcat (install/start/restart/upgrade).
- Enable safe upgrade patterns, including side-by-side candidate validation for near zero-downtime promotion.
- Maintain operational confidence through test automation (Kitchen suites, Make targets, upgrade/downgrade playbooks).

## Scope of This Repository
- Ansible role logic in `tasks/`, `defaults/`, `handlers/`, and `lookup_plugins/`.
- Test orchestration via Test Kitchen (`.kitchen.yml`, `.kitchen-win.yml`) and helper scripts/Make targets.
- Supporting docs in `docs/` for setup, testing, troubleshooting, candidate rollout, and service account guidance.

## Key Runtime Context
- Primary target OS: **Windows** (Tomcat install logic gated by `ansible_facts['os_family'] == 'Windows'`).
- Strong dependency on companion roles during tests: `windows-base`, `provision-windows-security`, `provision-java`.
- Primary ports: `8080` (active service) and `9080` (candidate service).

## Delivery & Validation Channels
- Local dev validation: Vagrant + VirtualBox + Test Kitchen.
- Cloud sandbox validation: Azure CLI + Kitchen/Azure and Makefile automation.
- CI-style checks: lint/syntax/test targets in `Makefile`.

## Security & Secrets Position
- Role supports custom service accounts.
- Credentials must be injected securely via secret stores/lookup plugins; do not commit plaintext credentials.
- Documented integrations include AWS Secrets Manager, Azure Key Vault, and HashiCorp Vault lookups.

## Constraints / Notes
- `.clinerules` requires memory-bank documentation for cross-agent handoff.
- `.clinerules` also requests references to k3s/ArgoCD patterns; no direct k3s/ArgoCD implementation was detected in this repository. Current memory bank captures this as an architectural guardrail rather than implemented code.