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

    struct EventDetails {
        uint256 eventId;
        string title;
        uint256 startTime;
        uint256 endTime;
        uint256 proposalCount;
        bool finalized;
        bool isTie;
        uint256[] proposalIds;
        string[] proposalTitles;
        uint256[] proposalVoteCounts;
    }

    uint256 public totalEvents;
    mapping(uint256 => VoteEvent) public events;
    mapping(uint256 => mapping(uint256 => Proposal)) public eventProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => uint256[]) public winningProposalIds;

    event EventCreated(uint256 indexed eventId, string title, uint256 startTime, uint256 endTime);
    event ProposalAdded(uint256 indexed eventId, uint256 indexed proposalId, string title);
    event Voted(uint256 indexed eventId, address indexed voter, uint256 indexed proposalId);
    event EventFinalized(uint256 indexed eventId, uint256[] winnerIds, bool isTie);

    modifier validEvent(uint256 _eventId) {
        require(_eventId >= 1 && _eventId <= totalEvents, "Data: Event does not exist");
        _;
    }

    // --- Admin Actions ---

    function createEvent(string calldata _title, uint256 _start, uint256 _end) external onlyAdmin {
        require(_start > block.timestamp, "Data: Start must be in the future");
        require(_end > _start, "Data: End must be after start");
        totalEvents++;
        VoteEvent storage newEvent = events[totalEvents];
        newEvent.eventId = totalEvents;
        newEvent.title = _title;
        newEvent.bounds = VotingLib.TimeBounds(_start, _end);
        emit EventCreated(totalEvents, _title, _start, _end);
    }

    function addProposal(uint256 _eventId, string calldata _title) external onlyAdmin validEvent(_eventId) {
        VoteEvent storage vEvent = events[_eventId];
        require(block.timestamp < vEvent.bounds.startTime, "Phase: Event already started");
        vEvent.proposalCount++;
        uint256 pId = vEvent.proposalCount;
        eventProposals[_eventId][pId] = Proposal(pId, _title, 0);
        emit ProposalAdded(_eventId, pId, _title);
    }

    // --- Read Actions ---

    function getEventDetails(uint256 _eventId) public view validEvent(_eventId) returns (EventDetails memory) {
        VoteEvent storage vEvent = events[_eventId];
        uint256 count = vEvent.proposalCount;

        uint256[] memory pIds    = new uint256[](count);
        string[]  memory pTitles = new string[](count);
        uint256[] memory pVotes  = new uint256[](count);

        for (uint256 i = 1; i <= count; i++) {
            Proposal storage p = eventProposals[_eventId][i];
            pIds[i - 1]    = p.id;
            pTitles[i - 1] = p.title;
            pVotes[i - 1]  = p.voteCount;
        }

        return EventDetails({
            eventId:            vEvent.eventId,
            title:              vEvent.title,
            startTime:          vEvent.bounds.startTime,
            endTime:            vEvent.bounds.endTime,
            proposalCount:      count,
            finalized:          vEvent.finalized,
            isTie:              vEvent.isTie,
            proposalIds:        pIds,
            proposalTitles:     pTitles,
            proposalVoteCounts: pVotes
        });
    }

    function getAllEvents() public view returns (
        uint256[] memory eventIds,
        string[]  memory titles,
        uint256[] memory startTimes,
        uint256[] memory endTimes,
        bool[]    memory finalized,
        bool[]    memory isTie
    ) {
        uint256 count = totalEvents;
        eventIds   = new uint256[](count);
        titles     = new string[](count);
        startTimes = new uint256[](count);
        endTimes   = new uint256[](count);
        finalized  = new bool[](count);
        isTie      = new bool[](count);

        for (uint256 i = 1; i <= count; i++) {
            VoteEvent storage e = events[i];
            eventIds[i - 1]   = e.eventId;
            titles[i - 1]     = e.title;
            startTimes[i - 1] = e.bounds.startTime;
            endTimes[i - 1]   = e.bounds.endTime;
            finalized[i - 1]  = e.finalized;
            isTie[i - 1]      = e.isTie;
        }
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

    function finalizeEvent(uint256 _eventId) external onlyAdmin validEvent(_eventId) {
        VoteEvent storage vEvent = events[_eventId];
        require(block.timestamp > vEvent.bounds.endTime, "Phase: Election still ongoing");
        require(!vEvent.finalized, "Status: Already finalized");
        require(vEvent.proposalCount > 0, "Data: No proposals in this event");

        uint256 maxVotes = 0;
        for (uint256 i = 1; i <= vEvent.proposalCount; i++) {
            if (eventProposals[_eventId][i].voteCount > maxVotes) {
                maxVotes = eventProposals[_eventId][i].voteCount;
            }
        }

        require(maxVotes > 0, "Data: No votes were cast");

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
