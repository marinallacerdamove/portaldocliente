import { mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import Dialog from './Dialog.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountDialog = (props = {}) =>
  mount(Dialog, {
    props: { title: 'Title', ...props },
    global: {
      stubs: {
        TeleportWithDirection: { template: '<div><slot /></div>' },
        OnClickOutside: { template: '<div><slot /></div>' },
        Button: {
          props: ['icon', 'label'],
          template: '<button :data-icon="icon">{{ label }}</button>',
        },
      },
    },
  });

describe('Dialog', () => {
  beforeEach(() => {
    // jsdom não implementa o <dialog> nativo
    HTMLDialogElement.prototype.close = vi.fn();
  });

  it('has no close X button by default (upstream behavior)', () => {
    const wrapper = mountDialog();

    expect(wrapper.find('[data-icon="i-lucide-x"]').exists()).toBe(false);
    expect(wrapper.find('form').classes()).not.toContain('relative');
  });

  it('shows the close X button when showCloseButton is set', async () => {
    const wrapper = mountDialog({ showCloseButton: true });
    const close = wrapper.find('[data-icon="i-lucide-x"]');

    expect(close.exists()).toBe(true);
    expect(wrapper.find('form').classes()).toContain('relative');

    await close.trigger('click');
    expect(wrapper.emitted('close')).toBeTruthy();
  });

  it('accepts the full width', () => {
    const wrapper = mountDialog({ width: 'full' });

    expect(wrapper.find('dialog').classes()).toContain('max-w-[95vw]');
  });
});
