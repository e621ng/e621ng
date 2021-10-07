## Vagrant Troubleshooting

#### Yarn install fails - EPROTO

Make sure that you have executed `vagrant up` as admin if you are on Windows, as vagrant will not be able to create symlinks otherwise.

If it still does not work after that, execute `yarn install` on your host machine instead.

#### Danbooru service fails with ruby\r: No such file or directory

Git has converted the files in your repository to Windows line-endings; you must disable this behavior and recreate your working directory to fix it.
```
git config core.autocrlf false
rm -rf *
git checkout -- .
```

#### VM does not start
In case the VM doesn't start with the error `VT-x not available` and the error description `WHvCapabilityCodeHypervisorPresent is FALSE!` the the following solution should resolve the issue:

This error usually occurs, when the `Hyper-V` or the `Windows Hypervisor Platform` features are activated. <br/>
To deactivate these features, press the windows key and enter `Turn Windows features on or off`, here you can deactivate both features by unchecking their respective checkboxes.
Don't forget to restart the computer after deactivating the features.

#### VM does not start with error VERR_INTNET_FLT_IF_NOT_FOUND or VM starts, but all external requests to it time out

The error means that the VM failed to create or connect to a host-only ethernet adapter. If it starts, but cannot be connected to, the adapter might be misconfigured, or the VM might be hijacking another adapter, like a VPN tunnel.

The following steps might fix it:
1. Open Settings (not Control Panel), then click on  "Network & Internet", and finally on "Change adapter options"
2. Right-click on all items in the window that opens, and disable all of them.
3. Open VirtualBox Manager, click on "File", and select "Host Network Manager".
4. Remove all entries in that list. Yes, all of them.
4. Run `vagrant up`. It will most likely result in an error again, this is normal.
5. In the network adapter options, only one network adapter should be active - the one that was just created. Turn it off, then on again.
6. Run `vagrant up` again. The error should be gone now.
7. Re-enable other network adapters. 
