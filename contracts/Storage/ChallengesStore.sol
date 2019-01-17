/*
Copyright: Ambrosus Technologies GmbH
Email: tech@ambrosus.com

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is “Incompatible With Secondary Licenses”, as defined by the Mozilla Public License, v. 2.0.
*/

pragma solidity ^0.4.23;

import "../Boilerplate/Head.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../Lib/SafeMathExtensions.sol";
import "../Configuration/Config.sol";
import "../Configuration/Consts.sol";
import "./ShelteringQueuesStore.sol";


contract ChallengesStore is Base {

    using SafeMath for uint8;
    using SafeMath for uint32;
    using SafeMath for uint64;
    using SafeMathExtensions for uint;

    struct Challenge {
        address sheltererId;
        bytes32 bundleId;
        address challengerId;
        uint feePerChallenge;
        uint64 creationTime;
        uint8 activeCount;
        uint sequenceNumber;
        uint64 bookedShelteringExpirationTime;
        mapping(address => bool) designatedShelterers;
    }

    mapping(bytes32 => Challenge) challenges;
    mapping(bytes32 => uint32) activeChallengesOnBundleCount;
    uint nextChallengeSequenceNumber;
    ShelteringQueuesStore storeQueues;
    Config config;

    constructor(Head _head, Config _config, ShelteringQueuesStore _shelteringQueuesStore) public Base(_head){
        nextChallengeSequenceNumber = 1;
        config = _config;
        storeQueues = _shelteringQueuesStore;
    }

    function() public payable {}

    function store(
        address sheltererId,
        bytes32 bundleId,
        address challengerId,
        uint feePerChallenge,
        uint64 creationTime,
        uint8 activeCount)
    public payable onlyContextInternalCalls returns (bytes32)
    {
        bytes32 challengeId = getChallengeId(sheltererId, bundleId);
        challenges[challengeId] = Challenge(
            sheltererId, 
            bundleId, 
            challengerId, 
            feePerChallenge, 
            creationTime, 
            activeCount,
            nextChallengeSequenceNumber,
            creationTime + config.SHELTERING_RESERVATION_TIME());

        for (uint8 i = 0; i < activeCount; i++) {
            Consts.SecondaryNodeType nodeType = getChallengeNodeType(nextChallengeSequenceNumber);
            address designatedShelterer = storeQueues.rotateRound(nodeType);
            challenges[challengeId].designatedShelterers[designatedShelterer] = true;
            incrementNextChallengeSequenceNumber(1);
        }

        activeChallengesOnBundleCount[bundleId] = activeChallengesOnBundleCount[bundleId].add(activeCount).castTo32();
        return challengeId;
    }

    function remove(bytes32 challengeId) public onlyContextInternalCalls {
        activeChallengesOnBundleCount[challenges[challengeId].bundleId] = activeChallengesOnBundleCount[
            challenges[challengeId].bundleId].sub(challenges[challengeId].activeCount).castTo32();
        delete challenges[challengeId];
    }

    function transferFee(address refundAddress, uint amountToReturn) public onlyContextInternalCalls {
        refundAddress.transfer(amountToReturn);
    }

    function getChallenge(bytes32 challengeId) public view returns (address, bytes32, address, uint, uint64, uint8, uint, uint64) {
        Challenge storage challenge = challenges[challengeId];
        return (
        challenge.sheltererId,
        challenge.bundleId,
        challenge.challengerId,
        challenge.feePerChallenge,
        challenge.creationTime,
        challenge.activeCount,
        challenge.sequenceNumber,
        challenge.bookedShelteringExpirationTime
        );
    }

    function getChallengeId(address sheltererId, bytes32 bundleId) public view onlyContextInternalCalls returns (bytes32) {
        return keccak256(abi.encodePacked(sheltererId, bundleId));
    }

    function decreaseActiveCount(bytes32 challengeId) public onlyContextInternalCalls {
        activeChallengesOnBundleCount[challenges[challengeId].bundleId] = activeChallengesOnBundleCount[
            challenges[challengeId].bundleId].sub(1).castTo32();
        challenges[challengeId].activeCount = challenges[challengeId].activeCount.sub(1).castTo8();
        challenges[challengeId].sequenceNumber++;
    }

    function getActiveChallengesOnBundleCount(bytes32 bundleId) public view onlyContextInternalCalls returns (uint32) {
        return activeChallengesOnBundleCount[bundleId];
    }

    function getNextChallengeSequenceNumber() public view onlyContextInternalCalls returns (uint) {
        return nextChallengeSequenceNumber;
    }

    function isDesignatedShelterer(address sheltererId, bytes32 challengeId) public view onlyContextInternalCalls returns (bool) {
        return challenges[challengeId].designatedShelterers[sheltererId];
    }

    function isNodeTypeAvailable(Consts.SecondaryNodeType nodeType, bytes32 challengeId) public view onlyContextInternalCalls returns (bool) {
        uint sequenceNumber = challenges[challengeId].sequenceNumber;
        Consts.SecondaryNodeType currentType = getChallengeNodeType(sequenceNumber);
        if (currentType == nodeType) {
            return true;
        }
        
        uint8 activeCount = challenges[challengeId].activeCount;
        if (nodeType == Consts.SecondaryNodeType.OMEGA) {
            if (activeCount > 2) {
                return true;
            }
            return getChallengeNodeType(sequenceNumber + activeCount - 1) == Consts.SecondaryNodeType.OMEGA;
        }
        uint divisor = config.ATLAS1_SHELTERING_DIVISOR();
        if (nodeType == Consts.SecondaryNodeType.SIGMA) {
            divisor = config.ATLAS2_SHELTERING_DIVISOR();
        }
        return checkDivisor(divisor, sequenceNumber, activeCount);
    }

    function checkDivisor(uint divisor, uint sequenceNumber, uint8 activeCount) private pure returns (bool) {
        if (activeCount > divisor) {
            return true;
        }
        uint first = sequenceNumber;
        uint last = sequenceNumber + activeCount - 1;
        return first.mod(divisor) > last.mod(divisor);
    }

    function incrementNextChallengeSequenceNumber(uint amount) private {
        nextChallengeSequenceNumber += amount;
    }

    function getChallengeNodeType(uint sequenceNumber) private view returns (Consts.SecondaryNodeType) {
        if (sequenceNumber.mod(config.ATLAS1_SHELTERING_DIVISOR()) == 0) {
            return Consts.SecondaryNodeType.ZETA;
        } else if (sequenceNumber.mod(config.ATLAS2_SHELTERING_DIVISOR()) == 0) {
            return Consts.SecondaryNodeType.SIGMA;
        }
        return Consts.SecondaryNodeType.OMEGA;
    }
}
