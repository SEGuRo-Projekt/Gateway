# SEGuRo secrets

- SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
- SPDX-License-Identifier: Apache-2.0

Managing secrets distributed across the platform.

## How it works

All secrets are stored as [age] encrypted files (`.age`).
The recipients for each secret file are defined in the [secrets.nix] file.
The [agenix] application takes care of creating and editing secrets using the
developers personal keys and the corresponding NixOS module decrypts the
secrets using the machine specific private keys when deployed on the platform.

## The [secrets.nix] file

The [secrets.nix] file is, as the name suggests, a file written in the
[Nix Language], but probably wont need to learn it to understand how it works
since Nix is often described as a "JSON with functions" style syntax.

It's contents boil down to an attribute set of filenames mapped to objects.
These object contain a single `publicKeys` attribute which is a list of all
public keys for which a file should be encrypted.

You can even generate the corresponding JSON file and make it pretty using [jq]
to get a feel for the file structure.

```
nix eval --file ./secrets.nix --json | jq
```

The `let`-`in` block at the beginning of the file introduces some variables to
make the secret definitions below less repetetive and less error-prone.

The main syntax elements you'll need are:

- Double quotes (`""`) enclose strings.
- Brackets (`[]`) enclose a list.
- Braces (`{}`) enclose an attibute set.
- `++` concatenates two lists.
- `=` is used to separate key and value in an attribute set.

The variables available for defining the `publicKeys` lists are:

- `userKeys`: An attribute set of lists of public keys.
- `systemKey`: An attribute set of public keys.
- `allUserKeys`: A list of all keys in the `userKeys` attribute set.
- `allSystemKeys`: A list of all keys in the `systemKey` attribute set.

Note that a user has a list of keys, e.g. for multiple development machines
while a system has a single unique key.

## Adding a new public key to [secrets.nix]

If there is a new private key for a user or a new system introduced in the
platform, you need to add that user's or system's key to the [secrets.nix].

#### Add a new user public key

If a user already listed in the `userKeys` attibute set you can just add the
key as a string to the users key list.

If the users is not listed yet, create a new attribute in the `userKeys`
set.

```nix
userKeys = {
  ...
  my-user = [
    ...
    "public ssh or age key"
  ];
};
```

#### Add a new system public key

If you're setting up a new system you need to add the new system's public key
to the `systemKey` attribute set. You can find the private key of that system
at `/var/lib/keys/seguro.key`.

```nix
systemKey = {
  ...
  my-system = [
    ...
    "public age key for /var/lib/keys/seguro.key"
  ];
};
```

## Adding a new secret file

You can add a new secret by adding a line at the bottom of [secrets.nix] that
specifies which public keys should be able to decrypt it:

```nix
  ...
  "my-new-secret.age".publicKeys = allSystemKeys ++ userKeys.my-user;
```

See the [secrets.nix section](#the-secretsnix-file) above for information about
the syntac.

You can then create the new file using the [agenix] cli:

```sh
agenix -e my-new-secret.age
```

This opens the editor specified in the `EDITOR` environment variable to
create/edit the new secret this secret is then encrypted for using all the
public keys that were specified in the [secrets.nix].

## Editing a secret file

You can only view and edit the secret files where your key is listed in the
public keys in [secrets.nix] for that file.

If you are listed in the recipients you can edit the secret using the [agenix]
cli:

```sh
agenix -e my-secret.age
```

This opens the text editor specified in the `EDITOR` environment variable to
edit a decrypted temporary form of the secret and reencrypts it afterwards.

If you don't have permissions to decrypt the file but want to create a new
one from scratch, you can delete the local file and regenerate it like
described in the [previous section](#adding-a-new-secret-file).

## Using a secret in the NixOS configuration

You should probably read the description and reference of [agenix] for a more
complete picture.

While understanding the [secrets.nix] is pretty simple,
editing the NixOS configurations probably requires some experience in the
[Nix Language].

The following are some examples for specific use cases.

### Adding a NixOS user password file

To assign a password to a user in the NixOS configuration we are using the
[`users.users.<name>.passwordFile`] NixOS option. This option expects a path
to a file containing the encrypted password for a user.

To generate a new password you should first create the password:

```sh
mkpasswd -m sha-512 > password.txt
```

This will interactively ask you for your password and write its sha-512 form
into a `password.txt` file.

You can then encrypt that file using the [agenix] cli:

```sh
agenix -e my-user-password.age < password.txt
```

This encrypts the contents of `password.txt` for all the recipients specified
in [secrets.nix]. You can now remove the `password.txt` file and add the `.age`
file to the Git tree.

You can now add the secret to your NixOS configuration:

```nix
{config, self, ...}: {
  age.secrets."my-user-password".file = self.secrets."my-user-password.age";
  users.users.my-user.passwordFile = config.age.secrets."my-user-password".path;
}
```

See the [users] nixos module for a complete user definition including the
[agenix] secrets.

[jq]: https://github.com/jqlang/jq
[Nix Language]: https://nixos.org/manual/nix/stable/language/index.html
[age]: https://age-encryption.org/
[agenix]: https://github.com/ryantm/agenix
[users]: ../nixosModules/users/default.nix
[secrets.nix]: ./secrets.nix
[`users.users.<name>.passwordFile`]: https://search.nixos.org/options?channel=23.05&query=users.users.<name>.passwordFile
