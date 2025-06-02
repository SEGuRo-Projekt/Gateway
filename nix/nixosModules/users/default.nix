# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

inputs: {
  users.users = rec {
    seguro = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      uid = 2001;

      initialPassword = "seguro";

      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDOE3YXkrCLbIEUVZglrmM2jyC2ZvmA/pE7ZzM1+CgaFba7BBoLHvMyk8TBy7/7V7qQAIqPiFg05qJ6k9v3Uf3fBKprM07hwcidKYhfdU49LRTdN4GJVlOvtGza/r4ctoznT10Nibz1BF0 0osbOkxbrhRTPVqRsqed/x9VGeAkJiZ+/7kuysMfD76cFxkcQ6e5/1dO3x0HcVub8FIZtHOv4ssFx63b5Gwy+Rto6bNYr6BT0qmczV2Ps2YL36IPaQw5AJ2jpABeOsCPJBtC8Qn8Q0mlPJEQ8ISj5UGYJ9+h3vcyFE2ywo2a6DSAJ//euScRHaxLMhTjZuuv32MeoZYZBfdGnS/CxmpM9vmbS3AXz3daZ0sAgc6QJAFuqGSwKYVykXhjMLPSmDgJjeTOJ6fSCCkFgxSTCDUfx/3gd1AVumHzvTpE0mBHzsNJai+s+ib8deKSqVAEZnHL14ThTanQBoUMoRYzhGg8tJCQdRcETZxF6qScl2qVk2ZCwL+a+Sdc= felix-wege"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9kuBu/eYcN1hNNIWEVfswO/rOoE1JVQPK+92Y6r856xrdaCpGOtHv5MBmO70fmGEFZ86e2QC0Ij5zqlwqTTNwWAHxT6H9d3CytThx54UronOCeQxQBYcJpLDSdY5MuseZjm0RlW+7aSNvnUttDByGBoCl+VWaaNF+dN2MWzrGIw0rvKJ24OVhPmm91VwOIoCJkKJ9AL1OEIpCH7n7jcaJYVBP2j+RVYfq47W4e9SfE/QlL+QVk360w+kFSeTybaMnsWALZNwk/kywzPq1dpw+4ToD6qBF6leY7ivD/ZsFppbndyzjW93PO3IWlTXmFd/UK/3xzihuZE9KWl0D1O5hny3o0DXkWK96xSFA4hhMqkVw0bNS9+jVq3fuaGNAtOUEg0rfCPPf0fwnPYq9pOyDUViGHDhMY/yWBSqlN+L3Rt9b8hwh0bhsAQiWF5ujIo3mivFD6BQQAyK52Qz778VRPK39k0gpYxqltcJEfjJ832arvNO9XseUKUQAi50gVyXfxD3yQK++0U1E9isF+VyLd1m5MgrtPlP20Ab2PJD6UUaMpr1rEldP9jVsGpVowntC/Hp4/ljCeppize4CRgZjWDHE+Yj+TWmVeuUTObniVWpE/eiQoDIe+FBWPeStq3UMPW5viUafzf2sCUxMyc/ZTUqy8wzDZEyfJ7OGaoxPrQ== yubikey@steffen-vogel"

        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFQFHx/0uPKgPWQIjQyQvun6EzSacx9qzcrHJVWpm5NeFrD5F3SwCPnSkmcm5Ctxnt9lN6aEdU0fN51W6H6mAzs= seguro-enclave@steffen-vogel"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBERI62l9pAbMxi6QYd3xnEMJhOY9NxcUOvgzNrJsDqSSRs5UgRjHCTDbw+7+yqr+ibcwDAcQgnzJEdRqsdhdTdc= yubikey@steffen-vogel"
      ];
    };

    root.openssh.authorizedKeys.keys = seguro.openssh.authorizedKeys.keys;
  };

  nix.settings.trusted-users = [
    "root"
    "seguro"
  ];
}
