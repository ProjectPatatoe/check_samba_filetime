icinga script to check file modified times over samba

Note: When contents of folder changes, folder modified time is updated

uses
* perl
* libsmbclient

perl uses...

    use Config::Simple;
	use Getopt::Long;
    use DateTime;
    use DateTime::Format::Duration;
    use DateTime::Format::Strptime qw();
    use Filesys::SmbClient;

options
-------
| Parameter                                | what 
| ---------                                | ---- 
| -v [0-3]                                 | 0 count results only, default <br/> 1 single-line, list warn/crit files/dir <br/> 2 multi-line, list files/dir + some options <br/> 3 multi-line, timestamps + full path + all options (login info)
| -d                                       | debug output (also -v 3)
| --fileonly                               | ignore directories
| -w [int], --age_warn [int]               | when warning is triggered in minutes
| -c [int], --age_crit [int]               | when critical is triggered in minutes
| --smb_path [str], --path [str]           | samba path (smb://host/share/dir)
| --smb_user [str], --user [str], --username [str] | username
| --smb_pass [str], --pass [str], --password [str] | password
| --smb_workgroup [str], --workgroup [str]         | workgroup / domain
| --smb_authfile [str], --authfile [str]           | path to file with auth info inside

authfile example
----------------
    username=bob
    password=cheese
    workgroup=home

"workgroup" can also be "domain" ex: `domain=home`

workgroup overrides domain if both are set

authfile overrides parameters