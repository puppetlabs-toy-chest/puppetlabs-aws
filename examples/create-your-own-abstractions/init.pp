import 'somegroup.pp' # import is deprecated and used here as an example only

somegroup { 'test-1': ami => 'ami-67a60d7a', region => 'sa-east-1' }
somegroup { 'test-2': ami => 'ami-67a60d7a', region => 'sa-east-1' }
somegroup { 'test-3': ami => 'ami-67a60d7a', region => 'sa-east-1' }
