let
  # Replace this with your age-formatted key (from ssh-to-age command)
  peter = "age12r45hgrcfsxvfvnyyp3td54qunhhtwmfaf4ejdrv9h0kakrtwc3s42hjuc";
  router = "age1gvu0eduzs9c4ehnfa04583tg39y0narwjf7qwaym92wzlzlmkfhsw23twv";
  
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
