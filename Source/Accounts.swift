import Foundation
import Combine

struct AccountRecord:Codable,Identifiable {
    let id:String
    var label:String
    var userID:String?=nil
}
@MainActor final class AccountManager:ObservableObject {
    private let persistAccounts:Bool
    private let makeModel:((String)->Model)?
    private var provisionalIDs=Set<String>()
    @Published var notice=""
    private static let recordsKey="linkCardAccounts"
    private static let activeKey="linkCardActiveAccount"
    @Published var records:[AccountRecord]
    @Published private(set) var activeID:String
    private var models:[String:Model]=[:]
    private var subscriptions:[String:AnyCancellable]=[:]
    var onSwitch:(()->Void)?
    private var statusNotifications=false
    var onNotification:((RequestEvent,AppLanguage)->Void)?
    func setNotifications(_ enabled:Bool) {statusNotifications=enabled;for model in models.values {model.setNotifications(enabled)}}
    var activeModel:Model {models[activeID]!}
    init(initialModel:Model?=nil,makeModel:((String)->Model)?=nil) {
        self.makeModel=makeModel
        persistAccounts=initialModel==nil
        let saved=UserDefaults.standard.data(forKey:Self.recordsKey).flatMap{try? JSONDecoder().decode([AccountRecord].self,from:$0)} ?? []
        var seen=Set<String>()
        var restored=initialModel == nil ? saved.filter{($0.id=="link" || UUID(uuidString:$0.id) != nil) && seen.insert($0.id).inserted} : []
        if restored.isEmpty {restored=[AccountRecord(id:"link",label:"")]}
        records=restored
        let selected=UserDefaults.standard.string(forKey:Self.activeKey) ?? "link"
        activeID=restored.contains(where:{$0.id==selected}) ? selected : restored[0].id
        provisionalIDs=Set(restored.filter{$0.id != "link" && $0.label.isEmpty}.map(\.id))
        for record in records {
            let model=initialModel ?? Model(api:record.id=="link" ? .shared : NativeLink(storageAccount:record.id))
            attach(model,id:record.id)
        }
    }
    private func attach(_ model:Model,id:String) {
        if persistAccounts {model.configureTemplates(account:id)}
        model.emitNotification={[weak self] event,language in self?.onNotification?(event,language)}
        model.setNotifications(statusNotifications)
        model.displayCredentials=false
        model.awaitingAccountAdmission=provisionalIDs.contains(id)
        model.accountAdmission={[weak self,weak model] identity in
            guard let self=self,let model=model else {return false}
            return try await self.admit(identity,model:model,id:id)
        }
        models[id]=model
        subscriptions[id]=model.$account.sink {[weak self] account in
            guard let account=account,!account.email.isEmpty else {return}
            Task {@MainActor [weak self] in
                guard let self=self,let index=self.records.firstIndex(where:{$0.id==id}) else {return}
                self.records[index].label=account.email
                self.records[index].userID=account.id.isEmpty ? nil : account.id
                self.save()
            }
        }
    }
    private func admit(_ identity:SignedInAccount,model:Model,id:String) async throws -> Bool {
        guard provisionalIDs.contains(id) else {return true}
        guard !identity.id.isEmpty || !identity.email.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {throw LinkError(message:"无法确认账户身份，请重新登录。",requiresLogin:true)}
        for record in records where record.id != id {
            guard let existing=models[record.id] else {continue}
            let otherID=existing.account?.id ?? record.userID ?? ""
            let email=existing.account?.email ?? record.label
            guard sameLinkAccount(id:identity.id,email:identity.email,otherID:otherID,otherEmail:email),await existing.api.hasSession() else {continue}
            // Delete only the newly authorized slot. Never touch the existing session.
            try await model.api.logout()
            model.detail=[];model.requests=[];model.methods=[];model.spendLimits=nil
            provisionalIDs.remove(id);records.removeAll{$0.id==id}
            subscriptions.removeValue(forKey:id);models.removeValue(forKey:id)
            if activeID==id {activeID=record.id;existing.detail=[];existing.displayCredentials=false;save();onSwitch?()}
            else {save()}
            notice="该账户已登录，已返回原账户。请在 Link 授权页面切换其他账户。"
            return false
        }
        provisionalIDs.remove(id)
        model.awaitingAccountAdmission=false
        return true
    }
    private func save() {
        guard persistAccounts else {return}
        UserDefaults.standard.set(try? JSONEncoder().encode(records),forKey:Self.recordsKey)
        UserDefaults.standard.set(activeID,forKey:Self.activeKey)
    }
    var canSwitch:Bool {!activeModel.busy && !activeModel.loggingIn && !activeModel.checkingAccount}
    func model(_ id:String)->Model? {models[id]}
    func select(_ id:String) {
        guard id != activeID,models[id] != nil,canSwitch else {return}
        notice=""
        activeModel.displayCredentials=false;activeModel.detail=[]
        activeID=id;save();onSwitch?()
    }
    func add(startLogin:Bool=true) {
        guard canSwitch else {return}
        let id=UUID().uuidString
        let model=makeModel?(id) ?? Model(api:NativeLink(storageAccount:id))
        model.checkingAccount=false
        provisionalIDs.insert(id)
        attach(model,id:id)
        records.append(AccountRecord(id:id,label:""))
        select(id)
        if startLogin {model.login()}
    }
    func startActive() {activeModel.start()}
}
