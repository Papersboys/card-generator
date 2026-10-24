import Foundation
import Combine

struct AccountRecord:Codable,Identifiable {
    let id:String
    var label:String
}
@MainActor final class AccountManager:ObservableObject {
    private static let recordsKey="linkCardAccounts"
    private static let activeKey="linkCardActiveAccount"
    @Published var records:[AccountRecord]
    @Published private(set) var activeID:String
    private var models:[String:Model]=[:]
    private var subscriptions:[String:AnyCancellable]=[:]
    var onSwitch:(()->Void)?
    var activeModel:Model {models[activeID]!}
    init(initialModel:Model?=nil) {
        let saved=UserDefaults.standard.data(forKey:Self.recordsKey).flatMap{try? JSONDecoder().decode([AccountRecord].self,from:$0)} ?? []
        var seen=Set<String>()
        var restored=initialModel == nil ? saved.filter{($0.id=="link" || UUID(uuidString:$0.id) != nil) && seen.insert($0.id).inserted} : []
        if restored.isEmpty {restored=[AccountRecord(id:"link",label:"")]}
        records=restored
        let selected=UserDefaults.standard.string(forKey:Self.activeKey) ?? "link"
        activeID=restored.contains(where:{$0.id==selected}) ? selected : restored[0].id
        for record in records {
            let model=initialModel ?? Model(api:record.id=="link" ? .shared : NativeLink(storageAccount:record.id))
            attach(model,id:record.id)
        }
    }
    private func attach(_ model:Model,id:String) {
        model.displayCredentials=false
        models[id]=model
        subscriptions[id]=model.$account.sink {[weak self] account in
            guard let account=account,!account.email.isEmpty else {return}
            Task {@MainActor [weak self] in
                guard let self=self,let index=self.records.firstIndex(where:{$0.id==id}) else {return}
                self.records[index].label=account.email
                self.save()
            }
        }
    }
    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(records),forKey:Self.recordsKey)
        UserDefaults.standard.set(activeID,forKey:Self.activeKey)
    }
    var canSwitch:Bool {!activeModel.busy && !activeModel.loggingIn && !activeModel.checkingAccount}
    func model(_ id:String)->Model? {models[id]}
    func select(_ id:String) {
        guard id != activeID,models[id] != nil,canSwitch else {return}
        activeModel.displayCredentials=false;activeModel.detail=[]
        activeID=id;save();onSwitch?()
    }
    func add() {
        guard canSwitch else {return}
        let id=UUID().uuidString
        let model=Model(api:NativeLink(storageAccount:id))
        model.checkingAccount=false
        attach(model,id:id)
        records.append(AccountRecord(id:id,label:""))
        select(id)
        model.login()
    }
    func startActive() {activeModel.start()}
}
