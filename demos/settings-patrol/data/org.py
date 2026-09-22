"""GitHub organization settings (github.com/organizations/<org>/settings), assembled from parts."""
import sys
from dsl import build
from org_a import O, top, access
from org_b import code
from org_c import security, third_party, integrations, archive, developer

if __name__ == "__main__":
    build("org", O, [top, access, code, security, third_party, integrations, archive, developer], sys.argv[1])
