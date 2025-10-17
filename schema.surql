DEFINE TABLE OVERWRITE user SCHEMALESS
    PERMISSIONS
        FOR select
            WHERE $auth.id == id
;

DEFINE FIELD OVERWRITE email ON user TYPE string VALUE $value.lowercase() ASSERT string::is::email($value);
DEFINE FIELD OVERWRITE password ON user TYPE string;
DEFINE FIELD OVERWRITE created ON user TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE email_unique ON user FIELDS email UNIQUE;

DEFINE ACCESS OVERWRITE account ON DATABASE TYPE RECORD
	SIGNUP ( CREATE user SET email = $email, password = crypto::argon2::generate($password) )
	SIGNIN ( SELECT * FROM user WHERE email = $email AND crypto::argon2::compare(password, $password) )
;


DEFINE TABLE pc SCHEMALESS
    PERMISSIONS
        FOR select FULL
;

DEFINE FIELD OVERWRITE name ON pc TYPE string VALUE $value.trim();
DEFINE FIELD OVERWRITE name_lower ON pc TYPE string VALUE $this.name.lowercase();
DEFINE FIELD created ON pc TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD user ON pc TYPE record<user> REFERENCE ON DELETE REJECT;
DEFINE FIELD key ON pc TYPE uuid DEFAULT rand::uuid::v4() READONLY
    PERMISSIONS
        FOR select
            WHERE $auth.id IN (id, user)
;

DEFINE INDEX OVERWRITE name_lower_unique ON pc FIELDS name_lower UNIQUE;

DEFINE ACCESS character ON DATABASE TYPE RECORD
    SIGNUP ( CREATE pc SET name=$name, user=<uuid>$user )
    SIGNIN ( SELECT * FROM pc WHERE name_lower=$name.lower().trim() AND user=<uuid>$user )
;