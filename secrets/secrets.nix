let
  # Convert your SSH public key to age format
  # Run: ssh-to-age < ~/.ssh/id_ed_nixinfra.pub 
  peter = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMFYKNEteD8lN4R6n2yfw1oVet2Tb4FVBpP/qcy5h06 peter@pop-os";

  # Add router host key after first boot:
  # router = "age1yyyy...";

  # Will add router host key after first boot
  users = [ peter ];
  # systems = [ router ];
  # all = users ++ systems;
in
{
  # Add secrets here when needed, example:
  # "some-password.age".publicKeys = users;
}