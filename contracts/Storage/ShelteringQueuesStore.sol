/*
Copyright: Ambrosus Technologies GmbH
Email: tech@ambrosus.com

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is “Incompatible With Secondary Licenses”, as defined by the Mozilla Public License, v. 2.0.
*/

pragma solidity ^0.4.23;

import "../Configuration/Consts.sol";
import "../Boilerplate/Head.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract ShelteringQueuesStore is Base {
    using SafeMath for uint;

    struct ShelteringQueueItem {
        address next;
        address prev;
        bool initialized;
    }

    struct ShelteringQueue {
        address headSheltererId;
        address tailSheltererId;
        uint size;
        mapping(address => ShelteringQueueItem) queueStorage;
    }

    mapping(bytes32 => ShelteringQueue) sheltererQueuesByType;

    constructor(Head _head) public Base(_head) {
        sheltererQueuesByType[keccak256(abi.encodePacked(Consts.SecondaryNodeType.OMEGA))] = ShelteringQueue(0,0,0);
        sheltererQueuesByType[keccak256(abi.encodePacked(Consts.SecondaryNodeType.SIGMA))] = ShelteringQueue(0,0,0);
        sheltererQueuesByType[keccak256(abi.encodePacked(Consts.SecondaryNodeType.ZETA))] = ShelteringQueue(0,0,0);
    }

    function rotateRound(Consts.SecondaryNodeType nodeType) public onlyContextInternalCalls returns (address) {
        require(!isQueueEmpty(nodeType), "Queue must not be empty");
        bytes32 queueId = keccak256(abi.encodePacked(nodeType));

        address head = sheltererQueuesByType[queueId].headSheltererId;
        removeShelterer(head, nodeType);
        addShelterer(head, nodeType);
        return head;
    }

    function addShelterer(address sheltererId, Consts.SecondaryNodeType nodeType) public onlyContextInternalCalls {
        require(!isInQueue(sheltererId, nodeType), "Shelterer must not be in queue");

        bytes32 queueId = keccak256(abi.encodePacked(nodeType));
        uint size = sheltererQueuesByType[queueId].size;
        if (size == 0) {
            sheltererQueuesByType[queueId].headSheltererId = sheltererId;
            sheltererQueuesByType[queueId].tailSheltererId = sheltererId;
            sheltererQueuesByType[queueId].queueStorage[sheltererId].initialized = true;
            sheltererQueuesByType[queueId].size = 1;
            return;
        }

        address tail = sheltererQueuesByType[queueId].tailSheltererId;
        sheltererQueuesByType[queueId].queueStorage[tail].next = sheltererId;
        sheltererQueuesByType[queueId].queueStorage[sheltererId].initialized = true;
        sheltererQueuesByType[queueId].queueStorage[sheltererId].prev = tail;
        sheltererQueuesByType[queueId].tailSheltererId = sheltererId;
        sheltererQueuesByType[queueId].size = size.add(1);
    }

    function removeShelterer(address sheltererId, Consts.SecondaryNodeType nodeType) public onlyContextInternalCalls {
        require(isInQueue(sheltererId, nodeType), "Shelterer must be in queue");
        bytes32 queueId = keccak256(abi.encodePacked(nodeType));

        address prev = sheltererQueuesByType[queueId].queueStorage[sheltererId].prev;
        address next = sheltererQueuesByType[queueId].queueStorage[sheltererId].next;
        if (isInQueue(prev, nodeType)) {
            sheltererQueuesByType[queueId].queueStorage[prev].next = next;
        }
        if (isInQueue(next, nodeType)) {
            sheltererQueuesByType[queueId].queueStorage[next].prev = prev;
        }

        if(sheltererId == sheltererQueuesByType[queueId].headSheltererId) {
            sheltererQueuesByType[queueId].headSheltererId = next;
        }
        if(sheltererId == sheltererQueuesByType[queueId].tailSheltererId) {
            sheltererQueuesByType[queueId].tailSheltererId = prev;
        }
        delete sheltererQueuesByType[queueId].queueStorage[sheltererId];
        sheltererQueuesByType[queueId].size = sheltererQueuesByType[queueId].size.sub(1);
    }

    function getHeadShelterer(Consts.SecondaryNodeType nodeType) public view returns (address) {
        bytes32 queueId = keccak256(abi.encodePacked(nodeType));
        return sheltererQueuesByType[queueId].headSheltererId;
    }

    function isInQueue(address sheltererId, Consts.SecondaryNodeType nodeType) public view returns (bool) {
        bytes32 queueId = keccak256(abi.encodePacked(nodeType));
        return sheltererQueuesByType[queueId].queueStorage[sheltererId].initialized;
    }

    function isQueueEmpty(Consts.SecondaryNodeType nodeType) public view  returns (bool) {
        bytes32 queueId = keccak256(abi.encodePacked(nodeType));
        return sheltererQueuesByType[queueId].size == 0;
    }
}