import json
import os
from vyos.configtree import ConfigTree

config_path = '/config/config.boot'

with open(config_path, 'r') as file:
    config_string = file.read()

config = ConfigTree(config_string=config_string)

interfaces = config.list_nodes(['interfaces', 'ethernet'])

# remove all hw-id from interfaces ethernet since it cause issue on interface order
# for interface in interfaces:
#     hw_id_path = ['interfaces', 'ethernet', interface, 'hw-id']
#     if config.exists(hw_id_path):
#         config.delete(hw_id_path)

# remove all interfaces ethernet 
for interface in interfaces:
    hw_id_path = ['interfaces', 'ethernet', interface]
    config.delete(hw_id_path)

# remove the name server the build sets to fetch packages, so it does not stay in the image
name_server_path = ['system', 'name-server']
if config.exists(name_server_path):
    config.delete(name_server_path)

# remove the user created by the installer from the saved config, so the image has no
# known login credential. vyos deletes the account on the next boot, since it is not in
# the config. only the saved config changes, the running build session is not affected,
# a live "delete system login user vyos" would fail as vyos is the current user.
if os.getenv('REMOVE_BUILD_USER') == 'true':
    user_path = ['system', 'login', 'user', 'vyos']
    if config.exists(user_path):
        config.delete(user_path)
    # deleting the last user leaves a bare "user" node behind, which is not valid config
    # and makes vyos drop the whole login node when it loads the config
    if config.exists(['system', 'login', 'user']) and not config.list_nodes(['system', 'login', 'user']):
        config.delete(['system', 'login', 'user'])
    # keep the login node even if empty, the login config script, which removes the
    # account at boot, only runs if the node exists
    if not config.exists(['system', 'login']):
        config.set(['system', 'login'])

with open(config_path, 'w') as config_file:
    config_file.write(config.to_string())
