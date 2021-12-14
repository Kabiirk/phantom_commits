# Phantom Commits

> Verbatim from [here](https://stackoverflow.com/a/3898842)

Unconditionally setting GIT_AUTHOR_DATE in an --env-filter would rewrite the date of every commit. Also, it would be unusual to use git commit inside --index-filter.

You are dealing with multiple, independent problems here.

## Specifying Dates Other Than “now”
Each commit has two dates: the author date and the committer date. You can override each by supplying values through the environment variables GIT_AUTHOR_DATE and GIT_COMMITTER_DATE for any command that writes a new commit. See “Date Formats” in git-commit(1) or the below:
```
Git internal format = <unix timestamp> <time zone offset>, e.g.  1112926393 +0200
RFC 2822            = e.g. Thu, 07 Apr 2005 22:13:13 +0200
ISO 8601            = e.g. 2005-04-07T22:13:13
```
The only command that writes a new commit during normal use is git commit. It also has a --date option that lets you directly specify the author date. Your anticipated usage includes git filter-branch --env-filter also uses the environment variables mentioned above (these are part of the “env” after which the option is named; see “Options” in git-filter-branch(1) and the underlying “plumbing” command git-commit-tree(1).

## Inserting a File Into a Single ref History
If your repository is very simple (i.e. you only have a single branch, no tags), then you can probably use git rebase to do the work.

In the following commands, use the object name (SHA-1 hash) of the commit instead of “A”. Do not forget to use one of the “date override” methods when you run git commit.
```
---A---B---C---o---o---o   master

git checkout master
git checkout A~0
git add path/to/file
git commit --date='whenever'
git tag ,new-commit -m'delete me later'
git checkout -
git rebase --onto ,new-commit A
git tag -d ,new-commit

---A---N                      (was ",new-commit", but we delete the tag)
        \
         B'---C'---o---o---o   master
If you wanted to update A to include the new file (instead of creating a new commit where it was added), then use git commit --amend instead of git commit. The result would look like this:

---A'---B'---C'---o---o---o   master
```
The above works as long as you can name the commit that should be the parent of your new commit. If you actually want your new file to be added via a new root commit (no parents), then you need something a bit different:
```
B---C---o---o---o   master

git checkout master
git checkout --orphan new-root
git rm -rf .
git add path/to/file
GIT_AUTHOR_DATE='whenever' git commit
git checkout -
git rebase --root --onto new-root
git branch -d new-root

N                       (was new-root, but we deleted it)
 \
  B'---C'---o---o---o   master
git checkout --orphan is relatively new (Git 1.7.2), but there are other ways of doing the same thing that work on older versions of Git.
```

## Inserting a File Into a Multi-ref History
If your repository is more complex (i.e. it has more than one ref (branches, tags, etc.)), then you will probably need to use git filter-branch. Before using git filter-branch, you should make a backup copy of your entire repository. A simple tar archive of your entire working tree (including the .git directory) is sufficient. git filter-branch does make backup refs, but it is often easier to recover from a not-quite-right filtering by just deleting your .git directory and restoring it from your backup.

Note: The examples below use the lower-level command git update-index --add instead of git add. You could use git add, but you would first need to copy the file from some external location to the expected path (--index-filter runs its command in a temporary GIT_WORK_TREE that is empty).

If you want your new file to be added to every existing commit, then you can do this:
```
new_file=$(git hash-object -w path/to/file)
git filter-branch \
  --index-filter \
    'git update-index --add --cacheinfo 100644 '"$new_file"' path/to/file' \
  --tag-name-filter cat \
  -- --all
git reset --hard
```
I do not really see any reason to change the dates of the existing commits with --env-filter 'GIT_AUTHOR_DATE=…'. If you did use it, you would have make it conditional so that it would rewrite the date for every commit.

If you want your new file to appear only in the commits after some existing commit (“A”), then you can do this:
```
file_path=path/to/file
before_commit=$(git rev-parse --verify A)
file_blob=$(git hash-object -w "$file_path")
git filter-branch \
  --index-filter '

    if x=$(git rev-list -1 "$GIT_COMMIT" --not '"$before_commit"') &&
       test -n "$x"; then
         git update-index --add --cacheinfo 100644 '"$file_blob $file_path"'
    fi

  ' \
  --tag-name-filter cat \
  -- --all
git reset --hard
```
If you want the file to be added via a new commit that is to be inserted into the middle of your history, then you will need to generate the new commit prior to using git filter-branch and add --parent-filter to git filter-branch:
```
file_path=path/to/file
before_commit=$(git rev-parse --verify A)

git checkout master
git checkout "$before_commit"
git add "$file_path"
git commit --date='whenever'
new_commit=$(git rev-parse --verify HEAD)
file_blob=$(git rev-parse --verify HEAD:"$file_path")
git checkout -

git filter-branch \
  --parent-filter "sed -e s/$before_commit/$new_commit/g" \
  --index-filter '

    if x=$(git rev-list -1 "$GIT_COMMIT" --not '"$new_commit"') &&
       test -n "$x"; then
         git update-index --add --cacheinfo 100644 '"$file_blob $file_path"'
    fi

  ' \
  --tag-name-filter cat \
  -- --all
git reset --hard
```
You could also arrange for the file to be first added in a new root commit: create your new root commit via the “orphan” method from the git rebase section (capture it in new_commit), use the unconditional --index-filter, and a --parent-filter like "sed -e \"s/^$/-p $new_commit/\"".