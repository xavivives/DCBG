pragma solidity ^0.4.13;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract Uumm
{
    using SafeMath for uint256;

    struct projectData
    {
        //Project identity
        address creator;
        string  name;
        bytes32  id;
        uint creationTimestamp;

        //Governance features
        uint256 requiredConcensus; //Represented in %*100. what % of the voting participants (not percentage of contributors) is required for a proposal to be approved
        uint256 requiredParticipation; //Represented in %*100.  what % of participation is required to resolve a proposal.
        uint totalSupply;

        //Proposal stuff
        uint256 proposalsIndex;
        uint256 [] pendingProposals;
        uint256 pendingProposalsLength;
        proposalData [] proposals;
        uint256 proposalExpiringTimeInSeconds; 
        
        //Contributors stuff 
        mapping (address=>uint256) contributorsRef; // points address to ContributorData index
        contributorData [] contributors;
    }
    
    enum proposalState
    {
        pending, //ongoing proposal, users can still vote
        approved, //succesfully resolved proposal, can't be change
        denied, //denied proposal, can't be changed
        expired //no minimum participation was reached
    }
    
    struct proposalData
    {
        uint256 id;
        address author;
        string title;
        string reference;
        uint256 valueAmount; 
        proposalState state;
        mapping (address=>int256) votes; //votes can be negative or positive
        uint256 positiveVotes;
        uint256 negativeVotes;
        uint creationTimestamp;
        uint256 totalSupply; //This is so we can easly calculate the percentage of positive and negative votes even after resolution
    }
    struct contributorData
    {
        uint256 id;
        address contributorAddress;
        string name;
        uint256 valueTokens;
        uint256 weiBalance;
        uint256 [] proposalsRef ;
    }

    struct userData
    {
        address userAddress;
        bytes32 [] projectsRef; //list of projects that she contributed to (including created)
    }

    mapping (bytes32 => projectData ) projects;
    mapping (address => userData ) users;
    projectData emptyProject;
    contributorData emptyContributor;
    uint256 precision = 10000; //multiplier to deal with integer divisions


    function Uumm() public
    {
    } 

    function GetProjectId (address projectCreator, uint256 nonce) pure public
        returns (bytes32)
    {
        return(keccak256(projectCreator, nonce));
    }

    function CreateProject(string name) public
    {
        bytes32 projectId = GetProjectId(msg.sender, users[msg.sender].projectsRef.length);

        projects[projectId].creator = msg.sender;
        projects[projectId].name = name;
        projects[projectId].id = projectId;
        projects[projectId].creationTimestamp = block.timestamp;
        projects[projectId].requiredConcensus = 61;
        projects[projectId].requiredParticipation = 30;
        projects[projectId].proposalExpiringTimeInSeconds = 0;
        projects[projectId].pendingProposalsLength = 0;

        //The first position of 'contributors' is empty so we accidentally don't default to it
        contributorData memory _emptyContributor;
        projects[projectId].contributors.push(_emptyContributor);

        //Creator will be the first contributor
        addContributor(projectId, msg.sender);

        //Creator recieves one single token
        AddValueTokens(projectId, msg.sender, 1); 
    }

    function GetProjectsLength( address userAddress) constant public
        returns (uint256)
    {
        return (users[userAddress].projectsRef.length);
    }

    function GetProjectIdByIndex(address userAddress, uint256 index) constant public
        returns (bytes32)
    {
        return (users[userAddress].projectsRef[index]);
    }

    function GetProjectDetails (bytes32 projectId) constant public
        returns (address, string, bytes32, uint, uint256, uint256, uint256 )
    {
        return(
            projects[projectId].creator,
            projects[projectId].name,
            projects[projectId].id,
            projects[projectId].creationTimestamp,
            projects[projectId].totalSupply,
            projects[projectId].requiredConcensus,
            projects[projectId].requiredParticipation
            );
    }
    
    //CRITICAL
    function AddValueTokens(bytes32 projectId, address contributor, uint256 valueAmount) private
    {
        uint256 contributorId = projects[projectId].contributorsRef[contributor];
        projects[projectId].contributors[contributorId].valueTokens = projects[projectId].contributors[contributorId].valueTokens.add(valueAmount);
        projects[projectId].totalSupply = projects[projectId].totalSupply.add(valueAmount);
    }

    function GetTotalSupply(bytes32 projectId) constant public
        returns (uint256)
    {
        return projects[projectId].totalSupply;
    }
    
    function CreateProposal (bytes32 projectId, string title, string reference, uint256 valueAmount) public
    {
        if(valueAmount==0)
            revert();

        uint256 proposalId =  projects[projectId].proposals.length;

        proposalData memory proposal;
        proposal.id = proposalId;
        proposal.author = msg.sender;
        proposal.title = title;
        proposal.reference = reference;
        proposal.valueAmount = valueAmount;
        proposal.state = proposalState.pending;
        proposal.creationTimestamp = block.timestamp;

        projects[projectId].proposals.push(proposal);
        
        projects[projectId].pendingProposals.push(proposalId);
        projects[projectId].pendingProposalsLength = projects[projectId].pendingProposalsLength.add(1);

        uint256 contributorId = projects[projectId].contributorsRef[msg.sender];

        //new contributor
        if(contributorId == 0)
        {  
            addContributor(projectId, msg.sender); 
            contributorId = projects[projectId].contributorsRef[msg.sender];  
        }

        projects[projectId].contributors[contributorId].proposalsRef.push(proposalId);    
    }

    function addContributor(bytes32 projectId, address contributorAddress) private
    {
        uint256 contributorId = projects[projectId].contributors.length;

        projects[projectId].contributors.push(emptyContributor);
        projects[projectId].contributors[contributorId].id = contributorId;
        projects[projectId].contributors[contributorId].contributorAddress = contributorAddress;

        projects[projectId].contributorsRef[contributorAddress] = contributorId;

        users[msg.sender].projectsRef.push(projectId);
    }
    
    function GetProposalsLength(bytes32 projectId) constant public returns (uint256)
    {
        return projects[projectId].proposals.length;
    }
   
    function GetPendingProposalsLength(bytes32 projectId) constant public returns (uint256)
    {
        return projects[projectId].pendingProposalsLength;
    }
    
    function  GetProposalDetails(bytes32 projectId, uint256 proposalId) constant public
        returns (uint256, address, string, string, uint256, uint)
    {
        return(
            projects[projectId].proposals[proposalId].id,
            projects[projectId].proposals[proposalId].author,
            projects[projectId].proposals[proposalId].title,
            projects[projectId].proposals[proposalId].reference,
            projects[projectId].proposals[proposalId].valueAmount,
            projects[projectId].proposals[proposalId].creationTimestamp
            );
    }

    //Proposal data is splited in two (GetProposalState and GetProposalDetails) because solidity doesn't allow to return more than 9 values
    //Proposal state is the data that changes over time plus id and creationTimestamp
    function  GetProposalState(bytes32 projectId, uint256 proposalId) constant public
        returns (uint256, proposalState, uint256, uint256, uint, uint256)
    {
        //proposal's totalSupply is only set once it's approved or dennied
        uint256 totalSupply = projects[projectId].proposals[proposalId].totalSupply;

        if(totalSupply==0)
            totalSupply = projects[projectId].totalSupply;

        return(
            projects[projectId].proposals[proposalId].id,
            projects[projectId].proposals[proposalId].state,
            projects[projectId].proposals[proposalId].positiveVotes,
            projects[projectId].proposals[proposalId].negativeVotes,
            projects[projectId].proposals[proposalId].creationTimestamp,
            totalSupply
            );
    }
    
    function GetPendingProposalId(bytes32 projectId, uint256 pendingIndex) constant public
        returns (uint256)
    {
        return projects[projectId].pendingProposals[pendingIndex];
    }
    
    //CRITICAL
    function VoteProposal(bytes32 projectId, uint256 proposalId, bool vote) public
    {
         uint256 contributorId  =   projects[projectId].contributorsRef[msg.sender];

        //Checks
        if (projects[projectId].proposals[proposalId].state != proposalState.pending)
            revert();

        if(projects[projectId].contributors[contributorId].valueTokens == 0)
            revert();

        if (HasExpired(projectId, proposalId))
            revert();
        
        //Reset the vote if she has voted already. 
        if(projects[projectId].proposals[proposalId].votes[msg.sender] > 0)
        {
            projects[projectId].proposals[proposalId].positiveVotes = projects[projectId].proposals[proposalId].positiveVotes.sub(uint256(projects[projectId].proposals[proposalId].votes[msg.sender]));
            //This fails for an unknown reason on local testrpc
            projects[projectId].proposals[proposalId].votes[msg.sender] = 0;
        }
        else if(projects[projectId].proposals[proposalId].votes[msg.sender] < 0)
        {
            projects[projectId].proposals[proposalId].negativeVotes = projects[projectId].proposals[proposalId].negativeVotes.sub(uint256(-1 * projects[projectId].proposals[proposalId].votes[msg.sender]));
            //This fails for an unknown reason on local testrpc
            projects[projectId].proposals[proposalId].votes[msg.sender] = 0;
        }
        
        //Vote
        if(vote)
        {
            projects[projectId].proposals[proposalId].positiveVotes = projects[projectId].proposals[proposalId].positiveVotes.add(projects[projectId].contributors[contributorId].valueTokens);
            projects[projectId].proposals[proposalId].votes[msg.sender] = int256(projects[projectId].contributors[contributorId].valueTokens);
        }
        else   
        {
            projects[projectId].proposals[proposalId].negativeVotes = projects[projectId].proposals[proposalId].negativeVotes.add(projects[projectId].contributors[contributorId].valueTokens);
            projects[projectId].proposals[proposalId].votes[msg.sender] = -1 * int256(projects[projectId].contributors[contributorId].valueTokens);
        }
    }
    
    //CRITICAL

    //Anyone can resolve the proposal
    //Proposal can be resolved in two scenarios (only if is pending):
    //1- Concensus is over 'requiredConcensus' among the all participants.
    //2- Expiration date has passed, and  'requiredParticipation' has been reached
    
    //TODO This function need to be expressed clearly. It is too convoluted right now.

    function ResolveProposal(bytes32 projectId, uint256 proposalId) public
    {

        if (projects[projectId].proposals[proposalId].state != proposalState.pending)
            revert();
            
        if(!HasEnoughParticipation(projectId, proposalId))
            revert();

        //Enough contributors have voted
        if(HasEnoughConcensus(projects[projectId].proposals[proposalId].positiveVotes, projects[projectId].totalSupply, projects[projectId].requiredConcensus))
        {
            ApproveOrDennyProposal(projectId, proposalId, true);
            return;
        }

        if(HasEnoughConcensus(projects[projectId].proposals[proposalId].negativeVotes, projects[projectId].totalSupply,projects[projectId].requiredConcensus))
        {
            ApproveOrDennyProposal(projectId, proposalId, false);
            return;
        }  

        //Deadline has expired
        if (HasExpired(projectId, proposalId))
        {
            if(projects[projectId].proposals[proposalId].positiveVotes > projects[projectId].proposals[proposalId].negativeVotes)
                ApproveOrDennyProposal(projectId, proposalId, true);
            else
                ApproveOrDennyProposal(projectId, proposalId, false);

            return;
        }
    }

    function ApproveOrDennyProposal (bytes32 projectId, uint256 proposalId, bool approved) private
    {
        projects[projectId].proposals[proposalId].totalSupply = projects[projectId].totalSupply;

        if(approved)
        {
            projects[projectId].proposals[proposalId].state = proposalState.approved;
            AddValueTokens(projectId, projects[projectId].proposals[proposalId].author, projects[projectId].proposals[proposalId].valueAmount);
        }
        else
        {
            projects[projectId].proposals[proposalId].state = proposalState.denied;
        }
    }

    function HasEnoughConcensus(uint256 votesAmount, uint256 totalSupply, uint256 requiredConcensus) constant public
        returns (bool)
    {
       return  SafeMath.mul(votesAmount,precision)/SafeMath.mul(totalSupply,precision) > requiredConcensus/100;
    } 
    
    //Checks if a proposal has enough participation to be resolved before the exipring date
    function HasEnoughParticipation(bytes32 projectId, uint256 proposalId) constant public
        returns (bool)
    {
        if((projects[projectId].proposals[proposalId].positiveVotes * precision +
            projects[projectId].proposals[proposalId].negativeVotes * precision) /
            projects[projectId].totalSupply * precision >
            (projects[projectId].requiredParticipation/100 ))
            return true;
        else
            return false;
    }

    function HasExpired(bytes32 projectId, uint256 proposalId) constant public
        returns (bool)
    {
        return SafeMath.add(projects[projectId].proposals[proposalId].creationTimestamp, projects[projectId].proposalExpiringTimeInSeconds) > block.timestamp;
    }

    function GetContributorVote(bytes32 projectId, uint256 proposalId, address contributor) constant public
    returns (int256)
    {
        return projects[projectId].proposals[proposalId].votes[contributor];
    }

    //CRITICAL
    function FundProject(bytes32 projectId) public payable
    {
        //TODO Make sure that the function consumes less gas than the one available in a block
        if (msg.value == 0)
            revert();

        uint256 factor = SafeMath.div(msg.value,projects[projectId].totalSupply); //by default integer divisions use floor
        for (uint256 i = 0; i < projects[projectId].contributors.length; i++)
        {
            projects[projectId].contributors[i].weiBalance = projects[projectId].contributors[i].weiBalance.add(SafeMath.mul(projects[projectId].contributors[i].valueTokens, factor));
        }
    }

    function WithdrawFunds(bytes32 projectId) public
    {
        uint256 contributorId = projects[projectId].contributorsRef[msg.sender];
        if(projects[projectId].contributors[contributorId].weiBalance == 0)
            revert();
            
        msg.sender.transfer(projects[projectId].contributors[contributorId].weiBalance);
    }

    function GetContributorId(bytes32 projectId, address contributorAddress) constant public
        returns (uint256)
    {
        return projects[projectId].contributorsRef[contributorAddress];
    }

    function GetContributorDataByAddress(bytes32 projectId, address contributorAddress)  constant public
        returns (uint256, address, string, uint256, uint256)
    {   
        uint256 contributorId = projects[projectId].contributorsRef[contributorAddress];
        if(contributorId==0)
            revert();

        return GetContributorData(projectId, contributorId);
    }

    function GetContributorData(bytes32 projectId, uint256 contributorId)  constant public
        returns (uint256, address, string, uint256, uint256)
    {
        return(
            projects[projectId].contributors[contributorId].id,
            projects[projectId].contributors[contributorId].contributorAddress,
            projects[projectId].contributors[contributorId].name,
            projects[projectId].contributors[contributorId].valueTokens,
            projects[projectId].contributors[contributorId].weiBalance
            );
    }

    function GetContributorsLength(bytes32 projectId)  constant public
        returns (uint256)
    {
        return(projects[projectId].contributors.length);
    }

    function GetContributorProposalsLength(bytes32 projectId, uint256 contributorId) constant public
        returns (uint256)
    {
        return(projects[projectId].contributors[contributorId].proposalsRef.length);
    }
}