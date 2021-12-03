//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AmplifyPlugins
import AWSMobileClient

@testable import Amplify
@testable import AmplifyTestCommon
@testable import AWSDataStoreCategoryPlugin

/*
 A one-to-one connection where a project has one team,
 with a field you would like to use for the connection.
 ```
 type Project2V2 @model @auth(rules: [{allow: public}]) {
   id: ID!
   name: String
   teamID: ID!
   team: Team2V2 @hasOne(fields: ["teamID"])
 }

 type Team2V2 @model @auth(rules: [{allow: public}]) {
   id: ID!
   name: String!
 }
 ```
 See https://docs.amplify.aws/cli/graphql-transformer/connection for more details
 */

class DataStoreConnectionScenario2V2Tests: SyncEngineIntegrationV2TestBase {

    func testSaveTeamAndProjectSyncToCloud() throws {
        try startAmplifyAndWaitForSync()
        let team = Team2V2(name: "name1")
        let project = Project2V2(teamID: team.id, team: team)
        let syncedTeamReceived = expectation(description: "received team from sync event")
        let syncProjectReceived = expectation(description: "received project from sync event")
        let hubListener = Amplify.Hub.listen(to: .dataStore,
                                             eventName: HubPayload.EventName.DataStore.syncReceived) { payload in
            guard let mutationEvent = payload.data as? MutationEvent else {
                XCTFail("Could not cast payload to mutation event")
                return
            }

            if let syncedTeam = try? mutationEvent.decodeModel() as? Team2V2,
               syncedTeam == team {
                syncedTeamReceived.fulfill()
            } else if let syncedProject = try? mutationEvent.decodeModel() as? Project2V2,
                      syncedProject == project {
                syncProjectReceived.fulfill()
            }
        }
        guard try HubListenerTestUtilities.waitForListener(with: hubListener, timeout: 5.0) else {
            XCTFail("Listener not registered for hub")
            return
        }

        let saveTeamCompleted = expectation(description: "save team completed")

        Amplify.DataStore.save(team) { result in
            switch result {
            case .success:
                saveTeamCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [saveTeamCompleted, syncedTeamReceived], timeout: networkTimeout)
        let saveProjectCompleted = expectation(description: "save project completed")
        Amplify.DataStore.save(project) { result in
            switch result {
            case .success:
                saveProjectCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }

        wait(for: [saveProjectCompleted, syncProjectReceived], timeout: networkTimeout)

        let queriedProjectCompleted = expectation(description: "query project completed")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let queriedProject):
                XCTAssertEqual(queriedProject, project)
                queriedProjectCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [queriedProjectCompleted], timeout: networkTimeout)
    }

    func testUpdateProjectWithAnotherTeam() throws {
        try startAmplifyAndWaitForSync()
        let team = Team2V2(name: "name1")
        let anotherTeam = Team2V2(name: "name1")
        var project = Project2V2(teamID: team.id, team: team)
        let expectedUpdatedProject = Project2V2(id: project.id, name: project.name, teamID: anotherTeam.id)
        let syncUpdatedProjectReceived = expectation(description: "received updated project from sync path")
        let hubListener = Amplify.Hub.listen(to: .dataStore,
                                             eventName: HubPayload.EventName.DataStore.syncReceived) { payload in
            guard let mutationEvent = payload.data as? MutationEvent else {
                XCTFail("Could not cast payload to mutation event")
                return
            }

            if let syncedUpdatedProject = try? mutationEvent.decodeModel() as? Project2V2,
               expectedUpdatedProject == syncedUpdatedProject {
                syncUpdatedProjectReceived.fulfill()
            }
        }
        guard try HubListenerTestUtilities.waitForListener(with: hubListener, timeout: 5.0) else {
            XCTFail("Listener not registered for hub")
            return
        }

        let saveTeamCompleted = expectation(description: "save team completed")
        Amplify.DataStore.save(team) { result in
            switch result {
            case .success:
                saveTeamCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [saveTeamCompleted], timeout: networkTimeout)
        let saveAnotherTeamCompleted = expectation(description: "save team completed")
        Amplify.DataStore.save(anotherTeam) { result in
            switch result {
            case .success:
                saveAnotherTeamCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [saveAnotherTeamCompleted], timeout: networkTimeout)

        let saveProjectCompleted = expectation(description: "save project completed")
        Amplify.DataStore.save(project) { result in
            switch result {
            case .success:
                saveProjectCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [saveProjectCompleted], timeout: networkTimeout)

        let updateProjectCompleted = expectation(description: "save project completed")
        project.teamID = anotherTeam.id
        project.team = anotherTeam
        Amplify.DataStore.save(project) { result in
            switch result {
            case .success:
                updateProjectCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [updateProjectCompleted], timeout: networkTimeout)

        let queriedProjectCompleted = expectation(description: "query project completed")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let queriedProjectOptional):
                XCTAssertNotNil(queriedProjectOptional)
                if let queriedProject = queriedProjectOptional {
                    XCTAssertEqual(queriedProject, project)
                    XCTAssertEqual(queriedProject.teamID, anotherTeam.id)
                }

                queriedProjectCompleted.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [queriedProjectCompleted, syncUpdatedProjectReceived], timeout: networkTimeout)
    }

    func testDeleteAndGetProject() throws {
        try startAmplifyAndWaitForSync()
        guard let team = saveTeam(name: "name"),
              let project = saveProject(teamID: team.id, team: team) else {
            XCTFail("Could not save team and project")
            return
        }

        let deleteProjectSuccessful = expectation(description: "delete project")
        Amplify.DataStore.delete(project) { result in
            switch result {
            case .success:
                deleteProjectSuccessful.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [deleteProjectSuccessful], timeout: TestCommonConstants.networkTimeout)
        let getProjectAfterDeleteCompleted = expectation(description: "get project after deleted complete")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let project2V2):
                XCTAssertNil(project2V2)
                getProjectAfterDeleteCompleted.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [getProjectAfterDeleteCompleted], timeout: TestCommonConstants.networkTimeout)
    }

    func testDeleteWithValidCondition() throws {
        try startAmplifyAndWaitForSync()
        guard let team = saveTeam(name: "name"),
              let project = saveProject(teamID: team.id, team: team) else {
            XCTFail("Could not save team and project")
            return
        }

        let deleteProjectSuccessful = expectation(description: "delete project")
        Amplify.DataStore.delete(project, where: Project2V2.keys.team.eq(team.id)) { result in
            switch result {
            case .success:
                deleteProjectSuccessful.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [deleteProjectSuccessful], timeout: TestCommonConstants.networkTimeout)
        let getProjectAfterDeleteCompleted = expectation(description: "get project after deleted complete")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let project2):
                XCTAssertNil(project2)
                getProjectAfterDeleteCompleted.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [getProjectAfterDeleteCompleted], timeout: TestCommonConstants.networkTimeout)
    }

    func testDeleteWithInvalidCondition() throws {
        try startAmplifyAndWaitForSync()
        guard let team = saveTeam(name: "name"),
              let project = saveProject(teamID: team.id, team: team) else {
            XCTFail("Could not save team and project")
            return
        }

        let deleteProjectFailed = expectation(description: "delete project")
        Amplify.DataStore.delete(project, where: Project2V2.keys.team.eq("invalidTeamId")) { result in
            switch result {
            case .success:
                XCTFail("Should have failed")
            case .failure(let error):
                guard case .invalidCondition = error else {
                    XCTFail("\(error)")
                    return
                }
                deleteProjectFailed.fulfill()
            }
        }
        wait(for: [deleteProjectFailed], timeout: TestCommonConstants.networkTimeout)
        let getProjectAfterDeleteCompleted = expectation(description: "get project after deleted complete")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let project2):
                XCTAssertNotNil(project2)
                getProjectAfterDeleteCompleted.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [getProjectAfterDeleteCompleted], timeout: TestCommonConstants.networkTimeout)
    }

    func testDeleteAlreadyDeletedItemWithCondition() throws {
        try startAmplifyAndWaitForSync()
        guard let team = saveTeam(name: "name"),
              let project = saveProject(teamID: team.id, team: team) else {
            XCTFail("Could not save team and project")
            return
        }
        let deleteProjectSuccessful = expectation(description: "delete project")
        Amplify.DataStore.delete(project) { result in
            switch result {
            case .success:
                deleteProjectSuccessful.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [deleteProjectSuccessful], timeout: TestCommonConstants.networkTimeout)
        let getProjectAfterDeleteCompleted = expectation(description: "get project after deleted complete")
        Amplify.DataStore.query(Project2V2.self, byId: project.id) { result in
            switch result {
            case .success(let project2V2):
                XCTAssertNil(project2V2)
                getProjectAfterDeleteCompleted.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [getProjectAfterDeleteCompleted], timeout: TestCommonConstants.networkTimeout)

        let deleteProjectSuccessful2 = expectation(description: "delete project")
        Amplify.DataStore.delete(project, where: Project2V2.keys.teamID == team.id) { result in
            switch result {
            case .success:
                deleteProjectSuccessful2.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [deleteProjectSuccessful2], timeout: TestCommonConstants.networkTimeout)
    }

    func testListProjectsByTeamID() throws {
        try startAmplifyAndWaitForSync()
        guard let team = saveTeam(name: "name") else {
            XCTFail("Could not save team")
            return
        }
        guard let project = saveProject(teamID: team.id, team: team) else {
            XCTFail("Could not save project")
            return
        }
        let listProjectByTeamIDCompleted = expectation(description: "list projects completed")
        let predicate = Project2V2.keys.teamID.eq(team.id)
        Amplify.DataStore.query(Project2V2.self, where: predicate) { result in
            switch result {
            case .success(let projects):
                XCTAssertEqual(projects.count, 1)
                XCTAssertEqual(projects[0].id, project.id)
                XCTAssertEqual(projects[0].teamID, team.id)
                listProjectByTeamIDCompleted.fulfill()
            case .failure(let error):
                XCTFail("\(error)")
            }
        }
        wait(for: [listProjectByTeamIDCompleted], timeout: TestCommonConstants.networkTimeout)
    }

    func saveTeam(id: String = UUID().uuidString, name: String) -> Team2V2? {
        let team = Team2V2(id: id, name: name)
        var result: Team2V2?
        let completeInvoked = expectation(description: "request completed")
        Amplify.DataStore.save(team) { event in
            switch event {
            case .success(let team):
                result = team
                completeInvoked.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [completeInvoked], timeout: TestCommonConstants.networkTimeout)
        return result
    }

    func saveProject(id: String = UUID().uuidString,
                     name: String? = nil,
                     teamID: String,
                     team: Team2V2? = nil) -> Project2V2? {
        let project = Project2V2(id: id, name: name, teamID: teamID, team: team)
        var result: Project2V2?
        let completeInvoked = expectation(description: "request completed")
        Amplify.DataStore.save(project) { event in
            switch event {
            case .success(let project):
                result = project
                completeInvoked.fulfill()
            case .failure(let error):
                XCTFail("failed \(error)")
            }
        }
        wait(for: [completeInvoked], timeout: TestCommonConstants.networkTimeout)
        return result
    }
}

extension Team2V2: Equatable {
    public static func == (lhs: Team2V2,
                           rhs: Team2V2) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
    }
}
extension Project2V2: Equatable {
    public static func == (lhs: Project2V2, rhs: Project2V2) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.teamID == rhs.teamID
    }
}
