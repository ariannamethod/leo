CC      ?= cc
CFLAGS  ?= -O2 -lm -Wall -Wextra
SANED    = -O1 -g -fsanitize=address,undefined -lm -Wall -Wextra

# AML velocity bridge — build & link the family language so an .aml script can
# drive Leo's breath (--aml). The language is vendored as SOURCE in ariannamethod/
# (built into libaml.a here, never committed as a binary — AML itself .gitignores
# *.a). VENDOR ONLY — no sibling/external checkout reference. If the vendored source
# is absent, a silent fallback (Leo runs full; --aml just reports it is not linked).
AML_SRC := ariannamethod/ariannamethod.c
AML_LIB :=
ifneq ($(wildcard $(AML_SRC)),)   # the ONLY AML source is the vendored copy in ariannamethod/
  AML_LIB   := ariannamethod/libaml.a
  AML_FLAGS := -DHAVE_AML -Iariannamethod
endif

.PHONY: all test asan tsan clean run dialogue-probe life-probe adaptive-probe state-swarm-ecology state-swarm-road-calibration state-swarm-alphabet state-swarm-organs state-swarm-settled-organs state-swarm-displacement-return state-swarm-displacement-anatomy state-swarm-displacement-incidence visible-branch-probe visible-branch-matrix visible-resonance-matrix deferred-wonder-matrix deferred-wonder-ecology deferred-wonder-constellation deferred-wonder-semantics deferred-wonder-attribution deferred-wonder-redirection deferred-wonder-appetite deferred-wonder-appetite-calibration deferred-wonder-appetite-reliability deferred-wonder-appetite-drift deferred-wonder-appetite-policy deferred-wonder-appetite-regret deferred-wonder-appetite-readiness deferred-wonder-appetite-holdout deferred-wonder-appetite-admission deferred-wonder-appetite-transport deferred-wonder-appetite-transport-chronology deferred-wonder-appetite-checkpoint deferred-wonder-appetite-checkpoint-life deferred-wonder-appetite-source-ecology-life deferred-wonder-appetite-cadence-life deferred-wonder-appetite-source-cadence-life deferred-wonder-appetite-shift-anatomy deferred-wonder-appetite-visible-signal deferred-wonder-appetite-natural-life deferred-wonder-appetite-temporal-counterfactual deferred-wonder-appetite-exchange-attribution deferred-wonder-appetite-external-life deferred-wonder-appetite-provenance-shadow deferred-wonder-appetite-matched-counterfactual deferred-wonder-appetite-population-causal-lift deferred-wonder-appetite-susceptibility-holdout deferred-wonder-appetite-flom-third-life deferred-wonder-father-path-localization deferred-wonder-capsule-path-factorial deferred-wonder-capsule-interaction-population deferred-wonder-negation-life deferred-wonder-answer-reference-life deferred-wonder-answer-scope-life deferred-wonder-comma-scope-life

all: leo

ariannamethod/libaml.a: $(AML_SRC) ariannamethod/ariannamethod.h
	$(CC) -O2 -Iariannamethod -c $(AML_SRC) -o ariannamethod/ariannamethod.o
	ar rcs $@ ariannamethod/ariannamethod.o

leo: leo.c $(AML_LIB)
	$(CC) leo.c $(CFLAGS) $(AML_FLAGS) -o leo $(AML_LIB) -lpthread

run: leo
	./leo

dialogue-probe: leo
	./scripts/shadow_dialogue_probe.sh

life-probe: leo
	./scripts/shadow_life_probe.sh

adaptive-probe: leo
	./scripts/adaptive_life_probe.sh

state-swarm-ecology: leo
	./scripts/state_swarm_ecology_matrix.sh

state-swarm-road-calibration: leo
	./scripts/state_swarm_road_calibration.sh

state-swarm-alphabet: leo
	./scripts/state_swarm_alphabet_matrix.sh

state-swarm-organs: leo
	./scripts/state_swarm_organ_matrix.sh

state-swarm-settled-organs: leo
	./scripts/state_swarm_settled_organ_matrix.sh

state-swarm-displacement-return: leo
	./scripts/state_swarm_displacement_return_matrix.sh

state-swarm-displacement-anatomy: leo
	./scripts/state_swarm_displacement_anatomy_matrix.sh

state-swarm-displacement-incidence: leo
	./scripts/state_swarm_displacement_incidence_matrix.sh

visible-branch-probe: leo
	LEO_VISIBLE_BRANCH_POLICY=local-v1 ./scripts/adaptive_life_probe.sh scripts/visible_branch_phases.txt

visible-branch-matrix: leo
	./scripts/visible_branch_matrix.sh

visible-resonance-matrix: leo
	LEO_MATRIX_PROTOCOL=local-v2-resonance ./scripts/visible_branch_matrix.sh

deferred-wonder-matrix: leo
	./scripts/deferred_wonder_recovery_matrix.sh

deferred-wonder-ecology: leo
	./scripts/deferred_wonder_ecology_matrix.sh

deferred-wonder-constellation: leo
	./scripts/deferred_wonder_constellation_matrix.sh

deferred-wonder-semantics: leo
	./scripts/deferred_wonder_semantic_matrix.sh

deferred-wonder-attribution: leo
	./scripts/deferred_wonder_attribution_matrix.sh

deferred-wonder-redirection: leo
	./scripts/deferred_wonder_redirection_matrix.sh

deferred-wonder-appetite: leo
	./scripts/deferred_wonder_appetite_matrix.sh

deferred-wonder-appetite-calibration: leo
	./scripts/deferred_wonder_appetite_calibration_matrix.sh

deferred-wonder-appetite-reliability: leo
	./scripts/deferred_wonder_appetite_reliability_matrix.sh

deferred-wonder-appetite-drift: leo
	./scripts/deferred_wonder_appetite_drift_matrix.sh

deferred-wonder-appetite-policy: leo
	./scripts/deferred_wonder_appetite_policy_matrix.sh

deferred-wonder-appetite-regret: leo
	./scripts/deferred_wonder_appetite_regret_matrix.sh

deferred-wonder-appetite-readiness: leo
	./scripts/deferred_wonder_appetite_readiness_matrix.sh

deferred-wonder-appetite-holdout: leo
	./scripts/deferred_wonder_appetite_holdout_matrix.sh

deferred-wonder-appetite-admission: leo
	./scripts/deferred_wonder_appetite_admission_matrix.sh

deferred-wonder-appetite-transport: leo
	./scripts/deferred_wonder_appetite_transport_matrix.sh

deferred-wonder-appetite-transport-chronology: leo
	./scripts/deferred_wonder_appetite_transport_chronology_matrix.sh

deferred-wonder-appetite-checkpoint: leo
	./scripts/deferred_wonder_appetite_checkpoint_matrix.sh

deferred-wonder-appetite-checkpoint-life: leo
	./scripts/deferred_wonder_appetite_checkpoint_life.sh

deferred-wonder-appetite-source-ecology-life: leo
	./scripts/deferred_wonder_appetite_source_ecology_life.sh

deferred-wonder-appetite-cadence-life: leo
	./scripts/deferred_wonder_appetite_cadence_life.sh

deferred-wonder-appetite-source-cadence-life: leo
	./scripts/deferred_wonder_appetite_source_cadence_life.sh

deferred-wonder-appetite-shift-anatomy: leo
	./scripts/deferred_wonder_appetite_shift_anatomy.sh

deferred-wonder-appetite-visible-signal: leo
	./scripts/deferred_wonder_appetite_visible_signal.sh

deferred-wonder-appetite-natural-life: leo
	./scripts/deferred_wonder_appetite_natural_life.sh

deferred-wonder-appetite-temporal-counterfactual: leo
	./scripts/deferred_wonder_appetite_temporal_counterfactual.sh

deferred-wonder-appetite-exchange-attribution: leo
	./scripts/deferred_wonder_appetite_exchange_attribution.sh

deferred-wonder-appetite-external-life: leo
	./scripts/deferred_wonder_appetite_external_life.sh

deferred-wonder-appetite-provenance-shadow: leo
	./scripts/deferred_wonder_appetite_provenance_shadow.sh

deferred-wonder-appetite-matched-counterfactual: leo
	./scripts/deferred_wonder_appetite_matched_counterfactual.sh

deferred-wonder-appetite-population-causal-lift: leo
	./scripts/deferred_wonder_appetite_population_causal_lift.sh

deferred-wonder-appetite-susceptibility-holdout: leo
	./scripts/deferred_wonder_appetite_susceptibility_holdout.sh

deferred-wonder-appetite-flom-third-life: leo
	./scripts/deferred_wonder_appetite_flom_third_life.sh

deferred-wonder-father-path-localization: leo
	./scripts/deferred_wonder_father_path_localization.sh

deferred-wonder-capsule-path-factorial: leo
	./scripts/deferred_wonder_capsule_path_factorial.sh

deferred-wonder-capsule-interaction-population: leo
	./scripts/deferred_wonder_capsule_interaction_population.sh

deferred-wonder-negation-life: leo
	./scripts/deferred_wonder_negation_life.sh

deferred-wonder-answer-reference-life: leo
	./scripts/deferred_wonder_answer_reference_life.sh

deferred-wonder-answer-scope-life: leo
	./scripts/deferred_wonder_answer_scope_life.sh

deferred-wonder-comma-scope-life: leo
	./scripts/deferred_wonder_comma_scope_life.sh

# unit tests — test_leo.c #includes leo.c with LEO_NO_MAIN
test: tests/test_leo.c leo.c
	$(CC) -DLEO_NO_MAIN tests/test_leo.c $(CFLAGS) -o tests/test_leo
	./tests/test_leo
	./scripts/test_shadow_dialogue_report.sh
	./scripts/test_prewonder_dialogue_report.sh
	./scripts/test_prewonder_shadow_dialogue_report.sh
	./scripts/test_wonder_address_dialogue_report.sh
	./scripts/test_wonder_appetite_dialogue_report.sh
	./scripts/test_wonder_appetite_calibration_dialogue_report.sh
	./scripts/test_wonder_appetite_reliability_dialogue_report.sh
	./scripts/test_wonder_appetite_drift_dialogue_report.sh
	./scripts/test_wonder_appetite_policy_dialogue_report.sh
	./scripts/test_wonder_appetite_regret_dialogue_report.sh
	./scripts/test_wonder_appetite_readiness_dialogue_report.sh
	./scripts/test_wonder_appetite_holdout_dialogue_report.sh
	./scripts/test_wonder_appetite_admission_dialogue_report.sh
	./scripts/test_wonder_appetite_transport_dialogue_report.sh
	./scripts/test_wonder_appetite_transport_chronology_dialogue_report.sh
	./scripts/test_wonder_appetite_checkpoint_dialogue_report.sh
	./scripts/test_state_swarm_ecology_matrix.sh
	./scripts/test_state_swarm_road_calibration.sh
	./scripts/test_state_swarm_alphabet_matrix.sh
	./scripts/test_state_swarm_organ_dialogue_report.sh
	./scripts/test_state_swarm_organ_matrix.sh
	./scripts/test_state_swarm_settled_organ_matrix.sh
	./scripts/test_state_swarm_displacement_return_matrix.sh
	./scripts/test_state_swarm_displacement_anatomy_log.sh
	./scripts/test_state_swarm_displacement_anatomy_report.sh
	./scripts/test_state_swarm_displacement_anatomy_matrix.sh
	./scripts/test_state_swarm_displacement_incidence_report.sh
	./scripts/test_state_swarm_displacement_incidence_matrix.sh
	./scripts/test_deferred_wonder_recovery_matrix.sh
	./scripts/test_deferred_wonder_ecology_matrix.sh
	./scripts/test_deferred_wonder_constellation_matrix.sh
	./scripts/test_deferred_wonder_semantic_matrix.sh
	./scripts/test_deferred_wonder_attribution_matrix.sh
	./scripts/test_deferred_wonder_redirection_matrix.sh
	./scripts/test_deferred_wonder_appetite_matrix.sh
	./scripts/test_deferred_wonder_appetite_calibration_matrix.sh
	./scripts/test_deferred_wonder_appetite_reliability_matrix.sh
	./scripts/test_deferred_wonder_appetite_drift_matrix.sh
	./scripts/test_deferred_wonder_appetite_policy_matrix.sh
	./scripts/test_deferred_wonder_appetite_regret_matrix.sh
	./scripts/test_deferred_wonder_appetite_readiness_matrix.sh
	./scripts/test_deferred_wonder_appetite_holdout_matrix.sh
	./scripts/test_deferred_wonder_appetite_admission_matrix.sh
	./scripts/test_deferred_wonder_appetite_transport_matrix.sh
	./scripts/test_deferred_wonder_appetite_transport_chronology_matrix.sh
	./scripts/test_deferred_wonder_appetite_checkpoint_matrix.sh
	./scripts/test_deferred_wonder_appetite_checkpoint_life.sh
	./scripts/test_deferred_wonder_appetite_source_ecology_life.sh
	./scripts/test_deferred_wonder_appetite_cadence_life.sh
	./scripts/test_deferred_wonder_appetite_source_cadence_life.sh
	./scripts/test_deferred_wonder_appetite_shift_anatomy.sh
	./scripts/test_deferred_wonder_appetite_visible_signal.sh
	./scripts/test_deferred_wonder_appetite_natural_life.sh
	./scripts/test_deferred_wonder_appetite_temporal_counterfactual.sh
	./scripts/test_deferred_wonder_appetite_exchange_attribution.sh
	./scripts/test_deferred_wonder_appetite_external_life.sh
	./scripts/test_deferred_wonder_appetite_provenance_shadow.sh
	./scripts/test_deferred_wonder_appetite_matched_counterfactual.sh
	./scripts/test_deferred_wonder_appetite_population_causal_lift.sh
	./scripts/test_deferred_wonder_appetite_susceptibility_holdout.sh
	./scripts/test_deferred_wonder_appetite_flom_third_life.sh
	./scripts/test_deferred_wonder_father_path_localization.sh
	./scripts/test_deferred_wonder_capsule_path_factorial.sh
	./scripts/test_deferred_wonder_capsule_interaction_population.sh
	./scripts/test_deferred_wonder_negation_life.sh
	./scripts/test_deferred_wonder_answer_reference_life.sh
	./scripts/test_deferred_wonder_answer_scope_life.sh
	./scripts/test_deferred_wonder_comma_scope_life.sh

# address + undefined behaviour sanitizers on the smoke run
asan: leo.c
	$(CC) leo.c $(SANED) -o leo.asan -lpthread
	./leo.asan

# thread sanitizer — the Chunk-4 async worker under a live --chat --async session
tsan: leo.c
	$(CC) leo.c -O1 -g -fsanitize=thread -lm -lpthread -Wall -Wextra -o leo.tsan

clean:
	rm -f leo leo.asan leo.tsan tests/test_leo *.state
