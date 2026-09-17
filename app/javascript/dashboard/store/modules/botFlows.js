import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import BotFlowsAPI from '../../api/botFlows';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
  },
};

export const getters = {
  getBotFlows(_state) {
    return _state.records.sort((a1, a2) => a1.id - a2.id);
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getBotFlows({ commit }) {
    commit(types.SET_BOT_FLOW_UI_FLAG, { isFetching: true });
    try {
      const response = await BotFlowsAPI.get();
      commit(types.SET_BOT_FLOWS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_BOT_FLOW_UI_FLAG, { isFetching: false });
    }
  },
  create: async function createBotFlow({ commit }, botFlowObj) {
    commit(types.SET_BOT_FLOW_UI_FLAG, { isCreating: true });
    try {
      const response = await BotFlowsAPI.create(botFlowObj);
      commit(types.ADD_BOT_FLOW, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_BOT_FLOW_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_BOT_FLOW_UI_FLAG, { isUpdating: true });
    try {
      const response = await BotFlowsAPI.update(id, updateObj);
      commit(types.EDIT_BOT_FLOW, response.data.payload);
      return response.data.payload;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_BOT_FLOW_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_BOT_FLOW_UI_FLAG, { isDeleting: true });
    try {
      await BotFlowsAPI.delete(id);
      commit(types.DELETE_BOT_FLOW, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_BOT_FLOW_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_BOT_FLOW_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.ADD_BOT_FLOW]: MutationHelpers.create,
  [types.SET_BOT_FLOWS]: MutationHelpers.set,
  [types.EDIT_BOT_FLOW]: MutationHelpers.update,
  [types.DELETE_BOT_FLOW]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
