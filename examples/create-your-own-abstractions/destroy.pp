import 'somegroup.pp' # import is deprecated and used here as an example only

somegroup { 'test-1': ensure => 'absent', ami => 'ami-67a60d7a', region => 'sa-east-1' }
somegroup { 'test-2': ensure => 'absent' , ami => 'ami-67a60d7a', region => 'sa-east-1' }
somegroup { 'test-3': ensure => 'absent', ami => 'ami-67a60d7a', region => 'sa-east-1' }
