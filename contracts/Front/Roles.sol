/*
Copyright: Ambrosus Technologies GmbH
Email: tech@ambrosus.com

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is “Incompatible With Secondary Licenses”, as defined by the Mozilla Public License, v. 2.0.
*/

pragma solidity ^0.4.23;

import "../Boilerplate/Head.sol";
import "../Configuration/Consts.sol";
import "../Configuration/Config.sol";
import "../Storage/AtlasStakeStore.sol";
import "../Front/KycWhitelist.sol";
import "../Storage/RolesStore.sol";
import "../Storage/ApolloDepositStore.sol";
import "../Middleware/ValidatorProxy.sol";


contract Roles is Base {

    AtlasStakeStore private atlasStakeStore;
    RolesStore private rolesStore;
    ApolloDepositStore private apolloDepositStore;
    ValidatorProxy private validatorProxy;
    KycWhitelist private kycWhitelist;
    Config private config;

    constructor(
        Head _head, 
        AtlasStakeStore _atlasStakeStore, 
        RolesStore _rolesStore, 
        ApolloDepositStore _apolloDepositStore, 
        ValidatorProxy _validatorProxy, 
        KycWhitelist _kycWhitelist,
        Config _config
    ) 
        public Base(_head) 
    { 
        atlasStakeStore = _atlasStakeStore;
        rolesStore = _rolesStore;
        apolloDepositStore = _apolloDepositStore;
        validatorProxy = _validatorProxy;
        kycWhitelist = _kycWhitelist;
        config = _config;
    }

    function() public payable {}

    function onboardAsAtlas(string nodeUrl) public payable {
        require(canOnboard(msg.sender, Consts.NodeType.ATLAS, msg.value));

        Consts.SecondaryNodeType nodeType = getNodeTypeForAtlas(msg.value);
        atlasStakeStore.depositStake.value(msg.value)(msg.sender, nodeType);

        rolesStore.setRole(msg.sender, Consts.NodeType.ATLAS);

        rolesStore.setUrl(msg.sender, nodeUrl);
    }

    function onboardAsApollo() public payable {
        require(canOnboard(msg.sender, Consts.NodeType.APOLLO, msg.value));

        apolloDepositStore.storeDeposit.value(msg.value)(msg.sender);
        rolesStore.setRole(msg.sender, Consts.NodeType.APOLLO);
        validatorProxy.addValidator(msg.sender, msg.value);
    }

    function onboardAsHermes(string nodeUrl) public {
        require(canOnboard(msg.sender, Consts.NodeType.HERMES, 0));

        rolesStore.setRole(msg.sender, Consts.NodeType.HERMES);
        rolesStore.setUrl(msg.sender, nodeUrl);
    }

    function retireAtlas() public {
        retire(msg.sender, Consts.NodeType.ATLAS);

        uint amountToTransfer = atlasStakeStore.releaseStake(msg.sender, this);
        msg.sender.transfer(amountToTransfer);
    }

    function retireApollo() public {
        retire(msg.sender, Consts.NodeType.APOLLO);

        uint amountToTransfer = apolloDepositStore.releaseDeposit(msg.sender, this);
        validatorProxy.removeValidator(msg.sender);
        msg.sender.transfer(amountToTransfer);
    }

    function retireHermes() public {
        retire(msg.sender, Consts.NodeType.HERMES);
    }

    function getOnboardedRole(address node) public view returns (Consts.NodeType) {
        return rolesStore.getRole(node);
    }

    function getUrl(address node) public view returns (string) {
        return rolesStore.getUrl(node);
    }

    function setUrl(string nodeUrl) public {
        rolesStore.setUrl(msg.sender, nodeUrl);
    }

    function canOnboard(address node, Consts.NodeType role, uint amount) public view returns (bool) {
        return kycWhitelist.hasRoleAssigned(node, role) && amount == kycWhitelist.getRequiredDeposit(node);
    }
    
    function getNodeTypeForAtlas(uint amount) public view returns (Consts.SecondaryNodeType) {
        if (amount == config.ATLAS3_STAKE()) {
            return Consts.SecondaryNodeType.OMEGA;
        } else if (amount == config.ATLAS2_STAKE()) {
            return Consts.SecondaryNodeType.SIGMA;
        } else if (amount == config.ATLAS1_STAKE()) {
            return Consts.SecondaryNodeType.ZETA;
        }
        return Consts.SecondaryNodeType.NONE;
    }

    function retire(address node, Consts.NodeType role) private {
        require(rolesStore.getRole(node) == role);

        if (role == Consts.NodeType.ATLAS || role == Consts.NodeType.HERMES) {
            rolesStore.setUrl(node, "");
        }
        rolesStore.setRole(node, Consts.NodeType.NONE);
    }
}
