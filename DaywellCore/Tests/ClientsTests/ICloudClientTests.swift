@testable import Clients
import CloudKit
import Foundation
import Persistence
import Testing

struct ICloudClientTests {
    @Test func partialFailurePreservesQuotaError() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue, userInfo: [
            CKPartialErrorsByItemIDKey: ["record": NSError(domain: CKErrorDomain, code: CKError.Code.quotaExceeded.rawValue)]
        ])
        #expect(ICloudMonitor.failureStatus(error) == .storageFull)
    }

    @Test(arguments: [
        (CKAccountStatus.available, ICloudSyncStatus.available),
        (.noAccount, .signedOut), (.restricted, .restricted),
        (.temporarilyUnavailable, .temporarilyUnavailable), (.couldNotDetermine, .needsAttention)
    ])
    func accountMapping(input: CKAccountStatus, expected: ICloudSyncStatus) {
        #expect(ICloudMonitor.accountStatus(input) == expected)
    }

    @Test(arguments: [
        (CKError.Code.networkUnavailable, ICloudSyncStatus.waitingForConnection),
        (.networkFailure, .waitingForConnection), (.notAuthenticated, .signedOut),
        (.quotaExceeded, .storageFull), (.serviceUnavailable, .temporarilyUnavailable),
        (.permissionFailure, .needsAttention)
    ])
    func errorsAreActionable(code: CKError.Code, expected: ICloudSyncStatus) {
        let underlying = NSError(domain: CKErrorDomain, code: code.rawValue)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134400, userInfo: [NSUnderlyingErrorKey: underlying])
        #expect(ICloudMonitor.failureStatus(wrapped) == expected)
    }

    @Test func accountCheckAndSetupNeverConfirmATransfer() {
        var state = ICloudTransferState()
        #expect(state.snapshot(account: .available).status == .noConfirmedSync)
        state.receive(id: UUID(), isTransfer: false, isImport: false, end: .now, failure: nil)
        #expect(state.lastConfirmedSync == nil)
        #expect(state.snapshot(account: .available).status == .noConfirmedSync)
    }

    @Test func overlappingTransfersAndFailuresPreserveObservedHistory() {
        var state = ICloudTransferState()
        let first = UUID(), second = UUID()
        let timestamp = Date(timeIntervalSince1970: 100)
        state.receive(id: first, isTransfer: true, isImport: true, end: nil, failure: nil)
        state.receive(id: second, isTransfer: true, isImport: false, end: nil, failure: nil)
        #expect(state.snapshot(account: .available).status == .syncing)
        state.receive(id: first, isTransfer: true, isImport: true, end: timestamp, failure: nil)
        #expect(state.snapshot(account: .available).status == .syncing)
        #expect(state.dataRevision == 1)
        state.receive(id: second, isTransfer: true, isImport: false, end: timestamp.addingTimeInterval(10), failure: .storageFull)
        #expect(state.snapshot(account: .available).status == .storageFull)
        #expect(state.lastConfirmedSync == timestamp)
        state.receive(id: UUID(), isTransfer: true, isImport: true, end: timestamp, failure: nil)
        #expect(state.snapshot(account: .available).status == .storageFull)
        state.receive(id: UUID(), isTransfer: false, isImport: false, end: timestamp, failure: nil)
        #expect(state.snapshot(account: .available).status == .storageFull)
        #expect(state.snapshot(account: .signedOut).status == .signedOut)
        state.receive(id: UUID(), isTransfer: true, isImport: false, end: timestamp.addingTimeInterval(20), failure: nil)
        #expect(state.snapshot(account: .available).status == .available)
        #expect(state.lastConfirmedSync == timestamp.addingTimeInterval(20))
    }
}
