
# Cedarbridge — Azure IT Ticketing Platform

**Personal Cloud Engineering Project | Azure · Terraform · Python · FastAPI**

## Project Overview

Cedarbridge is a simulated internal IT support platform designed to replace fragmented employee support requests with a centralized ticketing workflow.

The project focuses on designing, provisioning, and eventually operating a secure, cost-conscious Azure-hosted application using Infrastructure as Code and automated deployments.

## Business Problem

The fictional organization currently relies on emails and Microsoft Teams messages to handle employee IT issues. This creates inconsistent ticket ownership, limited status visibility, and no standardized record of issue resolution.

**Proposed Solution:** A centralized platform through which employees can submit and track requests while IT administrators can triage, assign, prioritize, and resolve tickets.

## Engineering Objectives

- Build a functional ticket submission and retrieval application.
- Design a secure, scalable architecture using Azure PaaS services.
- Provision and manage infrastructure using Terraform.
- Implement CI/CD through GitHub Actions.
- Apply identity, networking, monitoring, and cost-management principles.


## Solution Architecture

The diagram below compares Cedarbridge's current local proof of concept with the proposed Azure cloud architecture.

![Cedarbridge Architecture Diagram](Docs/Images/Cedarbridge%20Ticketing%20Platform%20Architecture.png)


## Current Implementation Status

| Capability | Status |
|---|---|
| Requirements and architecture | Documented |
| Local FastAPI application | Implemented |
| Local ticket submission and retrieval | Implemented |
| Terraform infrastructure definitions | Written and validated |
| Azure SQL deployment plan | Generated successfully |
| Azure infrastructure deployment | Pending |
| Azure SQL application integration | Pending |
| GitHub Actions CI/CD | In progress |
| Microsoft Entra authentication | Planned |

**Project Stage:** Local application proof of concept and Azure infrastructure deployment preparation.

The project is being built iteratively, with security, reliability, operational visibility, and cost efficiency considered throughout the design.


## Local Application Setup

Cedarbridge is an internal IT ticketing application
built using Python, FastAPI and HTML.

### Running Locally

1. Navigate to the App directory:

   cd App

2. Create a virtual environment:

   py -m venv .venv

3. Activate the environment:

   .\.venv\Scripts\Activate.ps1

4. Install dependencies:

   python -m pip install -r requirements.txt

5. Start the application:

   python -m uvicorn Main:app --reload

6. Open http://127.0.0.1:8000

### Current Functionality

- Submit IT support tickets
- Validate required information
- Generate unique ticket IDs and timestamps
- Retrieve tickets by their ID
- Temporarily store tickets in memory

### Limitations

Tickets disappear when the application restarts.
Azure SQL integration and Entra ID authentication
have not yet been implemented.
