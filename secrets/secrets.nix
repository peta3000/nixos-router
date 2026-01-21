let
  # Replace this with your age-formatted key (from ssh-to-age command)
  peter = "age12r45hgrcfsxvfvnyyp3td54qunhhtwmfaf4ejdrv9h0kakrtwc3s42hjuc";
  
  # Will add router host key after first boot
  # router = "age1yyyyyyyy...";
  
  users = [ peter ];
  # systems = [ router ];
  # all = users ++ systems;
in
{
  # Example secrets - uncomment and modify as needed
  "test-secret.age".publicKeys = users;
  # "wifi-password.age".publicKeys = users;
  # "api-key.age".publicKeys = users;
}
