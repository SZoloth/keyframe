import SwiftUI

struct CastView: View {
    @Environment(AppState.self) private var appState
    @State private var showForm = false
    @State private var editingId: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    formSection
                    characterList
                }
                .padding()
            }

            if appState.project.currentPhase == .cast && !appState.project.characters.isEmpty {
                proceedButton
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Cast of characters")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if !showForm && editingId == nil {
                Button {
                    showForm = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Form

    @ViewBuilder
    private var formSection: some View {
        if showForm || editingId != nil {
            let editing = editingId.flatMap { id in appState.project.characters.first { $0.id == id } }
            CharacterFormView(
                editing: editing,
                onSave: { char in
                    if let id = editingId {
                        appState.updateCharacter(id, name: char.name, role: char.role, visualDescription: char.visualDescription)
                    } else {
                        appState.addCharacter(char)
                    }
                    showForm = false
                    editingId = nil
                },
                onCancel: {
                    showForm = false
                    editingId = nil
                }
            )
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - List

    @ViewBuilder
    private var characterList: some View {
        if appState.project.characters.isEmpty && !showForm {
            VStack(spacing: 12) {
                Text("No characters yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Add characters to maintain visual consistency across frames.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button("Add character") { showForm = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ForEach(appState.project.characters) { character in
                CharacterRow(
                    character: character,
                    onEdit: { editingId = character.id },
                    onDelete: { appState.removeCharacter(character.id) }
                )
            }
        }
    }

    // MARK: - Proceed

    private var proceedButton: some View {
        VStack {
            Divider()
            Button {
                appState.setPhase(.frames)
            } label: {
                Text("Continue to frame generation")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .padding()
        }
    }
}

// MARK: - Character row

struct CharacterRow: View {
    let character: StoryboardCharacter
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(character.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption)
                Button("Delete", role: .destructive, action: onDelete)
                    .font(.caption)
            }
            Text(character.visualDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.Colors.separator)
        )
    }
}

// MARK: - Character form

struct CharacterFormView: View {
    let editing: StoryboardCharacter?
    let onSave: (StoryboardCharacter) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var role = ""
    @State private var visualDescription = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $name, prompt: Text("e.g., Sarah"))
                .textFieldStyle(.roundedBorder)

            TextField("Role", text: $role, prompt: Text("e.g., Restaurant manager"))
                .textFieldStyle(.roundedBorder)

            Text("Visual description")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $visualDescription)
                .font(.caption)
                .frame(minHeight: 60, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Button(editing == nil ? "Add character" : "Update") {
                    let character = StoryboardCharacter(
                        id: editing?.id ?? "char-\(UUID().uuidString)",
                        name: name.trimmingCharacters(in: .whitespaces),
                        role: role.trimmingCharacters(in: .whitespaces),
                        visualDescription: visualDescription.trimmingCharacters(in: .whitespaces)
                    )
                    onSave(character)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .disabled(!isValid)

                Button("Cancel", action: onCancel)
            }
            .controlSize(.small)
        }
        .onAppear {
            if let editing {
                name = editing.name
                role = editing.role
                visualDescription = editing.visualDescription
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !role.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
