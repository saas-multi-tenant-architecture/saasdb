# SaaS Multi-Tenant Architecture - SMTA 

## Introduction

*SaaS Multi-Tenant Architecture*, aka **SMTA**, is an open-source project designed to address these challenges by providing a ready-made solution that can be used to quickly bootstrap your SaaS. It exists for developers to rapidly create a structurally sound and secure multi-tenant database, integrated with tools used in many SaaS applications today.

The architecture is designed to be modular, scalable, and extensible to customize it to your needs, combine with backend solutions, like [Supabase](https://supabase.com/), and reduce the complexity of multi-tenancy so that you can focus on building your MVP.

**SMTA** offers a layered approach to tenant isolation that reduces the risk of data leakage at the database level, leaving you free to develop your application knowing that the question of "Are you allowed to be here?" is already answered. 

The core of **SMTA** is a series of PostgreSQL database scripts that create the structure which sits between the application and platform layers of your SaaS. There are no dependencies or complex extensions, so it is all *plain old school SQL* (the 50+ year old technology that just works).

The following table diagram illustrates the layered design:

| Layer | Description |
|--|--| 
| Application Layer | Your domain tables (_app/): projects, posts, documents, etc. → Accessed via DAL (CASL, Drizzle, Payload collections, Supabase client) |
| **SMTA Layer** | Tenant Infrastructure: orgs, units, memberships, roles, audit, billing, and SaaS-management → Accessed via *POSS* public.* SQL functions |
| Platform Layer | Authentication, Storage, Edge Functions: Supabase or PayloadCMS |

### Membership Has Its Privileges
In short, **SMTA** asks your authenticated users: "Are you a member of this tenant/organization/unit?" - a yes/no gate on row visibility that is plain and simple. Then within that answer, your application (using CASL or another RBAC tool) can ask, "Given that you have access, what are you allowed to do?" - an action authorization based on the user's role. 

### Extensible Connections

To further help speed development, **SMTA** offers some extensible connections to other common platforms. This not only speeds development, but is an essential part of the **SMTA** model in that **SMTA** does NOT provide any authentication or application-related services. 

These connections include integration with [Supabase](https://supabase.com/) and [PayloadCMS](https://payloadcms.com/), along with payment processors like [Stripe](https://stripe.com/) and [Lemon Squeezy](https://www.lemonsqueezy.com/).

- Supabase - **SMTA** leverages Supabase user authentication, and associated functions like ```auth.uid()```, to fully contain tenants within their respective organizations, along with database adjacent features like storage, edge functions, and Supabase Vault. Supabase does a tremendous job of providing a full-stack solution for a SaaS - **SMTA** just amplifies this functionality.
- PayloadCMS - **SMTA** works alongside Payload, also utilizing its authentication and storage capabilities, while providing a multi-tenant database layer outside of the core CMS functionality. 


## Goals

- Multi-tenant architecture within a single, shared PostgreSQL database
- PostgreSQL RLS (Row-Level Security) for tenant isolation
- Soft deletion, auditing, and payment processor billing integration
- Clear schema boundaries via SQL functions
- Integration with common platforms like Supabase and PayloadCMS


## Features

- Tenant isolation via PostgreSQL RLS
- Integration database roles with RBAC libraries like [CASL](https://casl.js.org/) 
- Soft deletion to prevent data loss and enable recovery
- No-Code Auditing to track changes and actions at the database level
- Payment processor integration for billing
- Segmented and Isolated SaaS Management tables
- SQL functions enhanced with schema boundaries


### Schemas

These are the schemas used to segment functionality and enforce security boundaries. Removing access to tables from the `public` schema is an additional security measure to help prevent accidental exposure of sensitive data so that all **SMTA** activity is routed through fully tested, secure SQL functions.

- `core`: identity, access, helper functions, audit logs

- `utils`: Utility functions shared across all tenants and schemas

- `platform`: SaaS-wide management, logs, and overrides (service role only)

- `public`: only for exposing SQL functions callable by clients (RPC)

- `app`: all tenant-specific application logic (customized for each SaaS application)


## Origin

**SMTA** is a *labor of love*. It was born out of the frustration of having a great SaaS idea, but always stumbling over the same issue: building a structurally sound multi-tenant database. In many fledgling projects building the elements of **SMTA** is put aside in the interest of expediency, but this creates substantial technical debt. When an application gains success, establishing a robust multi-tenant architecture can involve awkward workarounds that are annoying to the end-user, or are just too costly to re-write. In some cases, multi-tenancy is achieved using a 'one-database-per-tenant model', which can be more costly or lack cross-tenant integration (such as macro-analytics). The leads to a reduction in tenant isolation, security, or performance, and sometimes all three.

**SMTA** originated to help solve the problem of building a multi-tenant application from the ground up. A great SaaS idea shouldn't have to begin with the rudimentary tenant isolation question, which is something most SaaS need. Rather, focus on the problem you are trying to solve.

*Labor of Love: Hundreds of thousands of AI tokens were used to build this project so you don't have to!*