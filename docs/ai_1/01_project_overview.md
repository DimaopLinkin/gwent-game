# Project Overview and Design Principles

## 🚀 Goal
This document provides the foundational context and core rules governing the development of the Flutter game project. All future development decisions must adhere to these principles.

## ✨ Core Principles: Spec Driven Design (SDD)
The project adheres strictly to the **Specification Driven Design** methodology. This means that every feature, class, or component developed must be traceable back to a clear, written specification and business/technical requirement documented elsewhere in this knowledge base.

1.  **Source of Truth:** The primary source of truth for functionality is documentation (e.g., `docs/*.md` files), not the code itself.
2.  **Requirement First:** Development always starts with defining a specific requirement before writing any implementation code.
3.  **Testability:** Specifications must be written in a way that enables automated testing and clear verification of implemented features.

## 📱 Project Basics
*   **Type:** Mobile/Local Multiplayer Game (Flutter).
*   **Primary Target Platform:** iOS, with subsequent support for other platforms (Android, Web, etc.).
*   **Architecture Goal:** Modular, scalable, and maintainable code base that separates game logic from UI concerns.

## ⚙️ Development Guidelines
1.  All major architectural decisions must be documented before implementation.
2.  When modifying core systems, developers must refer back to the relevant specification document (e.g., `docs/02_game_specifications.md`).