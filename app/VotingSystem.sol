// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AccessControl.sol";
import "./VotingLib.sol";

contract VotingSystem is AccessControl {
    using VotingLib for VotingLib.TimeBounds;

    struct Proposal {
        uint256 id;
        string title;
        uint256 voteCount;
    }

    struct VoteEvent {
        uint256 eventId;
        string title;
        VotingLib.TimeBounds bounds;
        uint256 proposalCount;
        bool finalized;
        bool isTie;
    }

    uint256 public totalEvents;
    mapping(uint256 => VoteEvent) public events;
    // eventId => proposalId => Proposal details
    mapping(uint256 => mapping(uint256 => Proposal)) public eventProposals;
    // eventId => voterAddress => votedStatus
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    // eventId => winning proposal IDs (multiple if tie)
    mapping(uint256 => uint256[]) public winningProposalIds;

    // Fix #4: Emit logs for all major state changes
    event EventCreated(uint256 indexed eventId, string title, uint256 startTime, uint256 endTime);
    event ProposalAdded(uint256 indexed eventId, uint256 indexed proposalId, string title);
    event Voted(uint256 indexed eventId, address indexed voter, uint256 indexed proposalId);
    event EventFinalized(uint256 indexed eventId, uint256[] winnerIds, bool isTie);

    // Fix #7: Reject calls referencing nonexistent events
    modifier validEvent(uint256 _eventId) {
        require(_eventId >= 1 && _eventId <= totalEvents, "Data: Event does not exist");
        _;
    }

    // --- Admin Actions ---

    function createEvent(string calldata _title, uint256 _start, uint256 _end) external onlyAdmin {
        // Fix #3: Prevent creating events already in the past
        require(_start > block.timestamp, "Data: Start must be in the future");
        require(_end > _start, "Data: End must be after start");
        totalEvents++;
        VoteEvent storage newEvent = events[totalEvents];
        newEvent.eventId = totalEvents;
        newEvent.title = _title;
        newEvent.bounds = VotingLib.TimeBounds(_start, _end);
        emit EventCreated(totalEvents, _title, _start, _end);
    }

    function getEvent(uint256 _eventId) public view validEvent(_eventId) returns (
        string memory title,
        uint256 startTime,
        uint256 endTime,
        uint256 proposalCount,
        bool finalized,
        bool isTie,
        uint256[] memory winnerIds
    ) {
        VoteEvent storage vEvent = events[_eventId];
        return (
            vEvent.title,
            vEvent.bounds.startTime,
            vEvent.bounds.endTime,
            vEvent.proposalCount,
            vEvent.finalized,
            vEvent.isTie,
            winningProposalIds[_eventId]
        );
    }

    function addProposal(uint256 _eventId, string calldata _title) external onlyAdmin validEvent(_eventId) {
        VoteEvent storage vEvent = events[_eventId];
        require(block.timestamp < vEvent.bounds.startTime, "Phase: Event already started");

        vEvent.proposalCount++;
        uint256 pId = vEvent.proposalCount;
        eventProposals[_eventId][pId] = Proposal(pId, _title, 0);
        emit ProposalAdded(_eventId, pId, _title);
    }

    function getProposal(uint256 _eventId, uint256 _proposalId) public view validEvent(_eventId) returns (
        string memory title,
        uint256 voteCount
    ) {
        Proposal storage prop = eventProposals[_eventId][_proposalId];
        return (prop.title, prop.voteCount);
    }

    function getWinners(uint256 _eventId) public view validEvent(_eventId) returns (uint256[] memory) {
        return winningProposalIds[_eventId];
    }

    // --- User Actions ---

    function vote(uint256 _eventId, uint256 _proposalId) external validEvent(_eventId) {
        VoteEvent storage vEvent = events[_eventId];

        require(registeredVoters[msg.sender], "Auth: Not a registered voter");
        require(vEvent.bounds.isActive(), "Phase: Voting is not currently active");
        require(!hasVoted[_eventId][msg.sender], "Action: Already voted in this event");
        require(VotingLib.isValidId(_proposalId, vEvent.proposalCount), "Data: Invalid proposal ID");

        hasVoted[_eventId][msg.sender] = true;
        eventProposals[_eventId][_proposalId].voteCount++;
        emit Voted(_eventId, msg.sender, _proposalId);
    }

    // --- Finalization ---

    // Fix #1: Restrict finalization to admin only
    function finalizeEvent(uint256 _eventId) external onlyAdmin validEvent(_eventId) {
        VoteEvent storage vEvent = events[_eventId];
        require(block.timestamp > vEvent.bounds.endTime, "Phase: Election still ongoing");
        require(!vEvent.finalized, "Status: Already finalized");
        // Fix #5: Require at least one proposal exists
        require(vEvent.proposalCount > 0, "Data: No proposals in this event");

        uint256 maxVotes = 0;

        // First pass: find the maximum vote count
        for (uint256 i = 1; i <= vEvent.proposalCount; i++) {
            if (eventProposals[_eventId][i].voteCount > maxVotes) {
                maxVotes = eventProposals[_eventId][i].voteCount;
            }
        }

        // Fix #2: Revert if no votes cast
        require(maxVotes > 0, "Data: No votes were cast");

        // Second pass: collect all proposals that share the maximum vote count
        uint256[] storage winners = winningProposalIds[_eventId];
        for (uint256 i = 1; i <= vEvent.proposalCount; i++) {
            if (eventProposals[_eventId][i].voteCount == maxVotes) {
                winners.push(i);
            }
        }

        vEvent.isTie = winners.length > 1;
        vEvent.finalized = true;
        emit EventFinalized(_eventId, winners, vEvent.isTie);
    }
}
