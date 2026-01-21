let
  # Replace this with your age-formatted key (from ssh-to-age command)
  peter = "age12r45hgrcfsxvfvnyyp3td54qunhhtwmfaf4ejdrv9h0kakrtwc3s42hjuc";
  router = "age1aje4thxc5cqatdsqeg3kvyhzfaldmc0mqyk9le6fe9pvxc5f4udss828k5";
  
  users = [ peter ];
  systems = [ router ];
  all = users ++ systems;
in
{
  # Example secrets - uncomment and modify as needed
  "test-secret.age".publicKeys = all;
  # "wifi-password.age".publicKeys = users;
  # "api-key.age".publicKeys = users;
}
