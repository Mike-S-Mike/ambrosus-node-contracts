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
        uint sequenceNumber;
        bool active;
        address designatedSheltererId;
        uint64 bookedShelteringExpirationTime;
    }

    mapping(bytes32 => Challenge) challenges;
    mapping(bytes32 => uint32) activeChallengesCount;
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
    public payable onlyContextInternalCalls returns (bytes32[])
    {
        bytes32[] memory challengeIds = new bytes32[](activeCount);
        for (uint8 i = 0; i < activeCount; i++) {
            bytes32 challengeId = getChallengeId(sheltererId, bundleId, nextChallengeSequenceNumber);
            Consts.SecondaryNodeType nodeType = getNextChallengeNodeType();
            address designatedShelterer = storeQueues.rotateRound(nodeType);
            challenges[challengeId] = Challenge(
                sheltererId, 
                bundleId, 
                challengerId, 
                feePerChallenge, 
                creationTime, 
                nextChallengeSequenceNumber, 
                true,
                designatedShelterer, 
                creationTime + config.SHELTERING_RESERVATION_TIME());
            incrementNextChallengeSequenceNumber(1);
            challengeIds[i] = challengeId;
        }
        uint32 value = activeChallengesOnBundleCount[bundleId];
        activeChallengesOnBundleCount[bundleId] = value.add(activeCount).castTo32();
        bytes32 activeChallengeId = getActiveChallengeId(sheltererId, bundleId);
        activeChallengesCount[activeChallengeId] = activeChallengesCount[activeChallengeId].add(activeCount).castTo32();
        return challengeIds;
    }

    function remove(bytes32 challengeId) public onlyContextInternalCalls {
        activeChallengesOnBundleCount[challenges[challengeId].bundleId] = activeChallengesOnBundleCount[
            challenges[challengeId].bundleId].sub(1).castTo32();
        bytes32 activeChallengeId = getActiveChallengeId(challenges[challengeId].sheltererId, challenges[challengeId].bundleId);
        activeChallengesCount[activeChallengeId] = activeChallengesCount[activeChallengeId].sub(1).castTo32();
        delete challenges[challengeId];
    }

    function transferFee(address refundAddress, uint amountToReturn) public onlyContextInternalCalls {
        refundAddress.transfer(amountToReturn);
    }

    function getChallenge(bytes32 challengeId) public view returns (address, bytes32, address, uint, uint64, uint, bool, address, uint64) {
        Challenge storage challenge = challenges[challengeId];
        return (
        challenge.sheltererId,
        challenge.bundleId,
        challenge.challengerId,
        challenge.feePerChallenge,
        challenge.creationTime,
        challenge.sequenceNumber,
        challenge.active,
        challenge.designatedSheltererId,
        challenge.bookedShelteringExpirationTime
        );
    }

    function getActiveChallengesOnBundleCount(bytes32 bundleId) public view onlyContextInternalCalls returns (uint32) {
        return activeChallengesOnBundleCount[bundleId];
    }

    function getActiveChallenge(address sheltererId, bytes32 bundleId) public view onlyContextInternalCalls returns (bool) {
        bytes32 activeChallengeId = getActiveChallengeId(sheltererId, bundleId);
        return activeChallengesCount[activeChallengeId] > 0;
    }

    function getNextChallengeSequenceNumber() public view onlyContextInternalCalls returns (uint) {
        return nextChallengeSequenceNumber;
    }

    function getChallengeId(address sheltererId, bytes32 bundleId, uint sequence) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(sheltererId, bundleId, sequence));
    }

    function incrementNextChallengeSequenceNumber(uint amount) private {
        nextChallengeSequenceNumber += amount;
    }

    function getActiveChallengeId(address sheltererId, bytes32 bundleId) private view returns (bytes32) {
        return keccak256(abi.encodePacked(sheltererId, bundleId));
    }

    function getNextChallengeNodeType() private view returns (Consts.SecondaryNodeType) {
        if (nextChallengeSequenceNumber.mod(config.ATLAS1_SHELTERING_DIVISOR()) == 0) {
            return Consts.SecondaryNodeType.ZETA;
        } else if (nextChallengeSequenceNumber.mod(config.ATLAS2_SHELTERING_DIVISOR()) == 0) {
            return Consts.SecondaryNodeType.SIGMA;
        }
        return Consts.SecondaryNodeType.OMEGA;
    }
}
