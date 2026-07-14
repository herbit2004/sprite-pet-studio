import SwiftUI

struct TriggerRuleEditor: View {
    @Binding var rule: TriggerRule
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $rule.isEnabled).labelsHidden()
                Picker("触发器", selection: $rule.kind) {
                    ForEach(TriggerKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .frame(width: 190)
                Spacer()
                if rule.kind != .mouseLook {
                    LabeledContent("冷却") {
                        TextField("秒", value: $rule.cooldownSeconds, format: .number)
                            .frame(width: 52)
                        Text("秒")
                    }
                }
                Button(role: .destructive, action: remove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            parameters

            Text(rule.kind.helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(11)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12))
        }
    }

    @ViewBuilder
    private var parameters: some View {
        switch rule.kind {
        case .random:
            HStack {
                LabeledContent("最短") {
                    TextField("秒", value: $rule.minimumIntervalSeconds, format: .number).frame(width: 58)
                    Text("秒")
                }
                LabeledContent("最长") {
                    TextField("秒", value: $rule.maximumIntervalSeconds, format: .number).frame(width: 58)
                    Text("秒")
                }
                LabeledContent("权重") {
                    TextField("权重", value: $rule.randomWeight, format: .number).frame(width: 48)
                }
            }
        case .idle:
            LabeledContent("空闲时间") {
                TextField("秒", value: $rule.idleSeconds, format: .number).frame(width: 58)
                Text("秒")
            }
        case .mouseNear, .mouseLook:
            HStack {
                Picker("触发范围", selection: distanceConditionBinding) {
                    ForEach(DistanceCondition.allCases) { condition in
                        Text(condition.displayName).tag(condition)
                    }
                }
                .frame(width: 190)
                LabeledContent("桌宠中心距离") {
                    TextField("点", value: $rule.distance, format: .number).frame(width: 58)
                    Text("pt")
                }
            }
        case .activeAppChanged:
            TextField("应用 Bundle ID，例如 com.apple.Safari；留空匹配任意应用", text: $rule.stringValue)
        case .external:
            TextField("外部事件名称，例如 task-running", text: $rule.stringValue)
        case .manual:
            TextField("可选的手动事件名称", text: $rule.stringValue)
        case .scheduled:
            HStack {
                Stepper("\(String(format: "%02d", rule.hour)) 时", value: $rule.hour, in: 0...23)
                Stepper("\(String(format: "%02d", rule.minute)) 分", value: $rule.minute, in: 0...59)
            }
        default:
            EmptyView()
        }
    }

    private var distanceConditionBinding: Binding<DistanceCondition> {
        Binding(
            get: { rule.distanceCondition ?? .inside },
            set: { rule.distanceCondition = $0 }
        )
    }
}
