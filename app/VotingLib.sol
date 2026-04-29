// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library VotingLib {
    struct TimeBounds {
        uint256 startTime;
        uint256 endTime;
    }

    // Checks if the block timestamp is within the allowed window
    function isActive(TimeBounds memory bounds) internal view returns (bool) {
        return (block.timestamp >= bounds.startTime && block.timestamp <= bounds.endTime);
    }

    // Ensures the proposal ID exists within the event's range
    function isValidId(uint256 id, uint256 count) internal pure returns (bool) {
        return (id > 0 && id <= count);
    }
}