import axios from 'axios';
import actions from '../../conversations/actions/ticketActions';
import types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#ticketActions', () => {
  beforeEach(() => {
    commit.mockClear();
  });

  describe('#mergeCustomAttributes', () => {
    it('sends only the changed keys and removes the empty ones', async () => {
      axios.post.mockResolvedValue({
        data: { custom_attributes: { servico: 'Novo', outro: 'x' } },
      });

      await actions.mergeCustomAttributes(
        { commit },
        { conversationId: 7, changes: { servico: 'Novo', empresa: '' } }
      );

      expect(axios.post).toHaveBeenCalledWith(
        '/api/v1/conversations/7/custom_attributes',
        {
          custom_attributes: { servico: 'Novo' },
          merge: true,
          remove: ['empresa'],
        }
      );
      expect(commit).toHaveBeenCalledWith(
        types.UPDATE_CONVERSATION_CUSTOM_ATTRIBUTES,
        {
          conversationId: 7,
          customAttributes: {
            empresa: undefined,
            servico: 'Novo',
            outro: 'x',
          },
        }
      );
    });

    it('rejects so the caller can warn the agent', async () => {
      axios.post.mockRejectedValue(new Error('422'));

      await expect(
        actions.mergeCustomAttributes(
          { commit },
          { conversationId: 7, changes: { servico: 'Novo' } }
        )
      ).rejects.toThrow('422');
      expect(commit).not.toHaveBeenCalled();
    });
  });

  describe('#linkTicket', () => {
    it('links on the server and updates every changed conversation', async () => {
      axios.post.mockResolvedValue({
        data: {
          payload: [
            { id: 1, custom_attributes: { ticket_filhos_ids: '2' } },
            { id: 2, custom_attributes: { ticket_pai_id: '1' } },
          ],
        },
      });

      await actions.linkTicket(
        { commit },
        { conversationId: 1, relation: 'child', ticketId: 2 }
      );

      expect(axios.post).toHaveBeenCalledWith(
        '/api/v1/conversations/1/ticket_link',
        { relation: 'child', ticket_id: 2 }
      );
      expect(commit).toHaveBeenCalledTimes(2);
      expect(commit).toHaveBeenCalledWith(
        types.UPDATE_CONVERSATION_CUSTOM_ATTRIBUTES,
        { conversationId: 2, customAttributes: { ticket_pai_id: '1' } }
      );
    });
  });
});
