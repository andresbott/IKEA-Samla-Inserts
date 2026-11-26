# Makefile — render IKEA Samla insert STLs (and preview PNGs) from
# IKEA_Samla_Inserts.scad, grouped by use case. Each group -> files/<group>/.
#
# Add a group: give it a <GROUP>_DIR and a <GROUP>_COMMON -D fragment, list its
# .stl files (explicitly like MTG, or via a foreach/eval matrix like STORAGE),
# give each a target-specific PARAMS, add a phony aggregator, and list it under
# `all`. The generic %.stl / %.png rules do the actual rendering.

OPENSCAD   ?= openscad
CONVERT    ?= convert
SCAD       := IKEA_Samla_Inserts.scad
FILES_DIR  := files
# OpenSCAD $fn for the final render (CLI is never $preview, so this is the real one)
RESOLUTION ?= 64

# Wall / floor thickness in mm — shared by every group ("same wall settings").
INNER_WALL ?= 1.2
OUTER_WALL ?= 1.8
FLOOR      ?= 1

# Preview-image settings (%.png rule: OpenSCAD render -> ImageMagick trim + margin).
IMG_SIZE   ?= 1600,1600
IMG_COLOR  ?= Cornfield
IMG_BG     ?= rgb(255,255,229)
IMG_MARGIN ?= 7%
IMG_OPTS   ?= --imgsize=$(IMG_SIZE) --colorscheme=$(IMG_COLOR) --viewall --autocenter --render

default: help

#==========================================================================================
##@ Rendering
#==========================================================================================
.PHONY: all
all: mtg storage ## render every group (STLs + previews)

# ---- MTG group ---------------------------------------------------------------
# A halved-by-column insert set for an 11 L box, printed in two heights (bottom
# + top), each in two variants that differ only by Cell_rows (1 vs 2).

# Shared across every MTG piece. Box_size 11 (Andrés).
MTG_DIR    := $(FILES_DIR)/mtg
# Box_size: "5" | "11" | "22"
MTG_BOX    := 11
# Layer_marking: false | inside | outside
MTG_MARK   := false
MTG_COMMON = Box_size="$(MTG_BOX)";Inner_wall_thickness=$(INNER_WALL);Outer_wall_thickness=$(OUTER_WALL);Bottom_thickness=$(FLOOR);Layer_marking="$(MTG_MARK)";Resolution=$(RESOLUTION)

# -- Bottom section: 24-layer scheme, combine 4 (a 5-layer-tall slab at layer 1),
#    halved by column, one open column.
MTG_B_LAYERS  := 24
MTG_B_ACTIVE  := 1
MTG_B_COMBINE := 4
MTG_B_PART    := halve_column
MTG_B_COLS    := 1
MTG_B_WIDTHS  := []
MTG_B_COMMON = Layers=$(MTG_B_LAYERS);Active_layer=$(MTG_B_ACTIVE);Combine_layers=$(MTG_B_COMBINE);Part="$(MTG_B_PART)";Cell_columns=$(MTG_B_COLS);Column_widths=$(MTG_B_WIDTHS);$(MTG_COMMON)

# -- Top section: 6-layer scheme, combine 2 (layers 3-5), halved by column,
#    3 columns (two 70 mm + leftover). Part assumed halve_column (TODO confirm).
MTG_T_LAYERS  := 6
MTG_T_ACTIVE  := 3
MTG_T_COMBINE := 2
MTG_T_PART    := halve_column
MTG_T_COLS    := 3
MTG_T_WIDTHS  := [70,70]
MTG_T_COMMON = Layers=$(MTG_T_LAYERS);Active_layer=$(MTG_T_ACTIVE);Combine_layers=$(MTG_T_COMBINE);Part="$(MTG_T_PART)";Cell_columns=$(MTG_T_COLS);Column_widths=$(MTG_T_WIDTHS);$(MTG_COMMON)

MTG_STLS := \
	$(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_1row.stl \
	$(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_2row.stl \
	$(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_1row.stl \
	$(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_2row.stl
MTG_PNGS := $(MTG_STLS:.stl=.png)

# Each .stl and its .png share PARAMS; variants within a section differ by Cell_rows.
$(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_1row.stl $(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_1row.png: PARAMS = Cell_rows=1;$(MTG_B_COMMON)
$(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_2row.stl $(MTG_DIR)/IKEA_Samla_Inserts_MTG_bottom_2row.png: PARAMS = Cell_rows=2;$(MTG_B_COMMON)
$(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_1row.stl $(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_1row.png: PARAMS = Cell_rows=1;$(MTG_T_COMMON)
$(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_2row.stl $(MTG_DIR)/IKEA_Samla_Inserts_MTG_top_2row.png: PARAMS = Cell_rows=2;$(MTG_T_COMMON)

.PHONY: mtg
mtg: $(MTG_STLS) $(MTG_PNGS) ## render MTG STLs + previews -> files/mtg/

# ---- Storage group -----------------------------------------------------------
# General 11 L halved-by-column containers, classified by layer count under
# files/storage/<N>_layers/. Each sub-category renders every layer of an N-layer
# box, in a matrix of <cols>x<rows> grids. Add a layer count: add its active
# list, a $(foreach ... storage_piece ...) line, filter, and a storage-<N>l
# target below.
STORAGE_ROOT   := $(FILES_DIR)/storage
STORAGE_BOX    := 11
STORAGE_PART   := halve_column
STORAGE_GRIDS    := 1x1 1x2 2x1 2x2
STORAGE_2L_GRIDS := $(STORAGE_GRIDS)
STORAGE_4L_GRIDS := $(STORAGE_GRIDS) 3x3
# Additional_spacing = mm inset from the box on every side. Raised above the SCAD
# default (1) so the widest (top) layer fits the bed: each +1 shrinks the top
# layer ~2.2 mm in depth and ~1.1 mm in width.
STORAGE_SPACING := 2.5
# Total stack height in mm, split evenly across layers (overrides the SCAD's
# s11_height = 118, which fills the box to the rim). 116 -> 58 mm per 2-layer piece.
STORAGE_HEIGHT := 116
# per-piece PARAMS add Layers/Active_layer/Cell_columns/Cell_rows on top of this.
STORAGE_COMMON = Box_size="$(STORAGE_BOX)";s11_height=$(STORAGE_HEIGHT);Combine_layers=0;Part="$(STORAGE_PART)";Column_widths=[];Additional_spacing=$(STORAGE_SPACING);Inner_wall_thickness=$(INNER_WALL);Outer_wall_thickness=$(OUTER_WALL);Bottom_thickness=$(FLOOR);Layer_marking="false";Resolution=$(RESOLUTION)

# storage_piece,<layers>,<active>,<cols>,<rows> -> declares one .stl + shared PARAMS.
define storage_piece
STORAGE_STLS += $(STORAGE_ROOT)/$(1)_layers/IKEA_Samla_Inserts_storage_$(STORAGE_BOX)l_$(2)of$(1)_$(3)x$(4).stl
$(STORAGE_ROOT)/$(1)_layers/IKEA_Samla_Inserts_storage_$(STORAGE_BOX)l_$(2)of$(1)_$(3)x$(4).stl $(STORAGE_ROOT)/$(1)_layers/IKEA_Samla_Inserts_storage_$(STORAGE_BOX)l_$(2)of$(1)_$(3)x$(4).png: PARAMS = Layers=$(1);Active_layer=$(2);Cell_columns=$(3);Cell_rows=$(4);$(STORAGE_COMMON)
endef
# expand <layers> x <active list> x <grids>; grid "CxR" -> cols/rows via subst.
STORAGE_2L_ACTIVE := 1 2
STORAGE_4L_ACTIVE := 1 2 3 4
$(foreach a,$(STORAGE_2L_ACTIVE),$(foreach g,$(STORAGE_2L_GRIDS),$(eval $(call storage_piece,2,$(a),$(word 1,$(subst x, ,$(g))),$(word 2,$(subst x, ,$(g)))))))
$(foreach a,$(STORAGE_4L_ACTIVE),$(foreach g,$(STORAGE_4L_GRIDS),$(eval $(call storage_piece,4,$(a),$(word 1,$(subst x, ,$(g))),$(word 2,$(subst x, ,$(g)))))))

STORAGE_PNGS    := $(STORAGE_STLS:.stl=.png)
STORAGE_2L_STLS := $(filter $(STORAGE_ROOT)/2_layers/%,$(STORAGE_STLS))
STORAGE_4L_STLS := $(filter $(STORAGE_ROOT)/4_layers/%,$(STORAGE_STLS))

.PHONY: storage-2l
storage-2l: $(STORAGE_2L_STLS) $(STORAGE_2L_STLS:.stl=.png) ## render 11L 2-layer storage set -> files/storage/2_layers/

.PHONY: storage-4l
storage-4l: $(STORAGE_4L_STLS) $(STORAGE_4L_STLS:.stl=.png) ## render 11L 4-layer storage set -> files/storage/4_layers/

.PHONY: storage
storage: storage-2l storage-4l ## render all storage containers -> files/storage/

#------------------------------------------------------------------------------------------
# Generic recipes. Each concrete target supplies its own PARAMS (see group blocks above).
#   %.stl -> geometry;  %.png -> OpenSCAD image, trimmed + margined via ImageMagick.
#   FORCE (below) makes both always re-render instead of being skipped.
#------------------------------------------------------------------------------------------
%.stl: $(SCAD) Makefile FORCE | check-openscad
	@mkdir -p "$(@D)"
	@echo ">> rendering $@"
	@$(OPENSCAD) -o "$@" -D '$(PARAMS)' "$(SCAD)"

%.png: $(SCAD) Makefile FORCE | check-openscad check-convert
	@mkdir -p "$(@D)"
	@echo ">> rendering preview $@"
	@$(OPENSCAD) -o "$(@:.png=.raw.png)" $(IMG_OPTS) -D '$(PARAMS)' "$(SCAD)"
	@$(CONVERT) "$(@:.png=.raw.png)" -fuzz 3% -trim +repage -bordercolor '$(IMG_BG)' -border $(IMG_MARGIN) "$@"
	@rm -f "$(@:.png=.raw.png)"

#==========================================================================================
##@ Cleaning
#==========================================================================================
.PHONY: clean-mtg
clean-mtg: ## remove rendered MTG files (files/mtg/)
	@rm -rf "$(MTG_DIR)"
	@echo "✅ removed $(MTG_DIR)"

.PHONY: clean-storage
clean-storage: ## remove rendered storage files (files/storage/)
	@rm -rf "$(STORAGE_ROOT)"
	@echo "✅ removed $(STORAGE_ROOT)"

.PHONY: clean
clean: clean-mtg clean-storage ## remove all rendered group files

# FORCE (always out of date) makes every render re-run instead of being skipped.
.PHONY: FORCE
FORCE:

.PHONY: check-openscad
check-openscad:
	@command -v $(OPENSCAD) >/dev/null 2>&1 || { echo "❌ '$(OPENSCAD)' not found — install OpenSCAD or set OPENSCAD=<path>"; exit 1; }

.PHONY: check-convert
check-convert:
	@command -v $(CONVERT) >/dev/null 2>&1 || { echo "❌ '$(CONVERT)' (ImageMagick) not found — needed for preview images, or set CONVERT=<path>"; exit 1; }

#==========================================================================================
#  Help
#==========================================================================================
.PHONY: help
help: # Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
