import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension APIRequestPanel {
    @ViewBuilder
    func tabContent(_ route: APIRoute) -> some View {
        switch builderTab {
        case .params: paramsTab(route)
        case .headers: EditablePairList(
                pairs: $vm.requestDraft.headers,
                keyPlaceholder: "Header",
                valuePlaceholder: "Value",
                keySuggestions: Self.commonHeaders,
                variableNames: vm.variableNames
            )
        case .body: bodyTab(route)
        }
    }

    func paramsTab(_ route: APIRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.requestDraft.pathParams.isEmpty {
                sectionLabel("PATH")
                EditablePairList(
                    pairs: $vm.requestDraft.pathParams,
                    keyPlaceholder: "Name",
                    valuePlaceholder: "Value",
                    lockKeys: true,
                    variableNames: vm.variableNames
                )
            }
            sectionLabel("QUERY")
            EditablePairList(
                pairs: $vm.requestDraft.query,
                keyPlaceholder: "Key",
                valuePlaceholder: "Value",
                variableNames: vm.variableNames
            )
            fieldsReference(route)
        }
    }

    func bodyTab(_ route: APIRoute) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KTSegmentedTabs(
                items: RequestBodyMode.allCases.map { .init(value: $0, label: $0.label) },
                selection: $vm.requestDraft.bodyMode
            )
            Group {
                switch vm.requestDraft.bodyMode {
                case .none:
                    Text("No request body").font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
                case .json:
                    TextEditor(text: $vm.requestDraft.bodyText)
                        .font(.jbMono(12))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: 0xFBFBFC)))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(KTColor.fieldBorder, lineWidth: 0.5))
                case .form:
                    EditablePairList(
                        pairs: $vm.requestDraft.formFields,
                        keyPlaceholder: "Key",
                        valuePlaceholder: "Value",
                        variableNames: vm.variableNames
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            fieldsReference(route)
        }
    }

    @ViewBuilder
    func fieldsReference(_ route: APIRoute) -> some View {
        if !route.rulesResolved {
            HStack(spacing: 7) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("Validation rules unavailable for this route.").font(.jbMono(11.5))
            }
            .foregroundStyle(Color(hex: 0xC07A00))
            .padding(.top, 4)
        } else if !route.fields.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("RULES")
                ForEach(route.fields, id: \.name) { field in
                    HStack(alignment: .top, spacing: 8) {
                        Text(field.name).font(.jbMono(12, .medium)).foregroundStyle(KTColor.ink2)
                        if field.required {
                            Text("required").font(.jbMono(10, .bold)).foregroundStyle(KTColor.danger)
                        }
                        Spacer(minLength: 8)
                        Text(field.rules.joined(separator: " · "))
                            .font(.jbMono(11)).foregroundStyle(KTColor.faint)
                            .frame(maxWidth: 220, alignment: .trailing)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text).font(.jbMono(11, .bold)).foregroundStyle(KTColor.ink3)
    }
}
