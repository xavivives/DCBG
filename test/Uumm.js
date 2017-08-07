var Uumm = artifacts.require("./Uumm.sol");

const initialSateResults = {
    projectsLength : 0,
    projectId:0,
    proposalsLength:0,
    pendingProposalsLength:0,
    proposalDetails:
    {
        proposalId:"",
        author:"",
        title:0,
        reference:0,
        valueAmount:0,
        creationDate:0
    }
}

const arguments = {
    unexistingProjectId:"32bytesString",
    unexistingProposalId:123
}

const errors = 
{
    VmException:"Uncaught Error: Error: VM Exception while executing eth_call: invalid opcode",
    InvalidOpcode:"Error: VM Exception while executing eth_call: invalid opcode"
}

contract('Uumm', async function(accounts)
{

    let projectCreator = accounts[0]

    let uummInstance = await  Uumm.deployed()

    it("...validate initial state data", async function()
    {
        //ProjectLength
        let projectsLength = await uummInstance.GetProjectsLength.call(projectCreator, {from: projectCreator});
        assert.equal (projectsLength.toNumber(), initialSateResults.projectsLength, "No project should exist yet");

        //Unexisting project Id
        uummInstance.GetProjectIdByIndex.call(projectCreator, 0, {from: projectCreator})
        .then(assert.fail)
         .catch(function(error) {
                assert(
                    error.message.indexOf(errors.InvalidOpcode) !== -1,
                    'No project should exist yet: It should throw:'+errors.InvalidOpcode
                )
         });

        //ProposalLength
        let proposalsLength = await uummInstance.GetProposalsLength.call(arguments.unexistingProjectId, {from: projectCreator});
        assert.equal (proposalsLength.toNumber(), initialSateResults.proposalsLength, "No proposal should exist yet"); 

        //PendingProposalLength
        let pendingProposalsLength = await uummInstance.GetPendingProposalsLength.call(arguments.unexistingProjectId, {from: projectCreator});
        assert.equal (pendingProposalsLength.toNumber(), initialSateResults.pendingProposalsLength, "No pending proposal should exist yet");

        //ProposalDetails
        uummInstance.GetProposalDetails.call(arguments.unexistingProjectId, arguments.unexistingProposalId, {from: projectCreator})
        .then(assert.fail)
         .catch(function(error) {
                assert(
                    error.message.indexOf(errors.InvalidOpcode) !== -1,
                    'No proposal exists yet: It should throw'+errors.InvalidOpcode
                )
         });

        //ProposalDetails - id
        //assert.equal(proposalDetails[0], initialSateResults.proposalDetails.proposalId, "Uninitialized proposal id should be empty");
        //ProposalDetails - author
        //assert.equal(proposalDetails[1], initialSateResults.proposalDetails.author, "Uninitialized proposal id should be empty");

        //proposalData.id = proposalDetails[0].toNumber()
        //proposalData.author = proposalDetails[1]
        //proposalData.title = proposalDetails[2]
        //proposalData.reference = proposalDetails[3]
        //proposalData.valueAmount = proposalDetails[4].toNumber()
        //proposalData.creationDate = new Date (proposalDetails[5].toNumber()*1000)

    });


    it("...should create a project named 'Project 1'.", function() {

        let projectName = "Project1";

        uummInstance.CreateProject(projectName, {from: projectCreator})
        .then(function() {

            uummInstance.GetProjectsLength.call(accounts[0])
            .then(function(numberOfProjects) {

                assert.isNumber(numberOfProjects.toNumber(), "Should return number");
                assert.equal(numberOfProjects.toNumber(), 1, "One single project should exist");

            });
        });
    });    
});
