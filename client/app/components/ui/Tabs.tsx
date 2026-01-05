import {
  useState,
  useRef,
  useCallback,
  useId,
  type ReactNode,
  type KeyboardEvent,
} from 'react';
import { cn } from '~/lib/utils';

export interface Tab {
  /** Unique identifier for the tab */
  id: string;
  /** Label displayed in the tab button */
  label: ReactNode;
  /** Content displayed when tab is active */
  content: ReactNode;
  /** Whether the tab is disabled */
  disabled?: boolean;
  /** Optional icon to display before the label */
  icon?: ReactNode;
}

export interface TabsProps {
  /** Array of tab objects */
  tabs: Tab[];
  /** ID of the currently active tab */
  activeTab?: string;
  /** Callback when active tab changes */
  onChange?: (tabId: string) => void;
  /** Additional CSS classes for the container */
  className?: string;
  /** Additional CSS classes for the tab list */
  tabListClassName?: string;
  /** Additional CSS classes for tab panels */
  panelClassName?: string;
  /** Visual variant */
  variant?: 'default' | 'pills' | 'underline';
  /** Whether tabs should take full width */
  fullWidth?: boolean;
}

/**
 * Accessible Tabs component with keyboard navigation.
 * Follows WAI-ARIA tabs pattern with proper roles and keyboard support.
 *
 * @example
 * <Tabs
 *   tabs={[
 *     { id: 'overview', label: 'Overview', content: <Overview /> },
 *     { id: 'details', label: 'Details', content: <Details /> },
 *     { id: 'history', label: 'History', content: <History /> },
 *   ]}
 *   activeTab={activeTab}
 *   onChange={setActiveTab}
 * />
 *
 * @example
 * <Tabs
 *   tabs={tabs}
 *   variant="pills"
 *   fullWidth
 * />
 */
export function Tabs({
  tabs,
  activeTab: controlledActiveTab,
  onChange,
  className,
  tabListClassName,
  panelClassName,
  variant = 'default',
  fullWidth = false,
}: TabsProps) {
  // Support both controlled and uncontrolled modes
  const [internalActiveTab, setInternalActiveTab] = useState(
    tabs[0]?.id || ''
  );
  const activeTab = controlledActiveTab ?? internalActiveTab;
  const tabListRef = useRef<HTMLDivElement>(null);
  const baseId = useId();

  const handleTabChange = useCallback(
    (tabId: string) => {
      if (onChange) {
        onChange(tabId);
      } else {
        setInternalActiveTab(tabId);
      }
    },
    [onChange]
  );

  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      const enabledTabs = tabs.filter((tab) => !tab.disabled);
      const currentIndex = enabledTabs.findIndex((tab) => tab.id === activeTab);

      let newIndex = currentIndex;

      switch (event.key) {
        case 'ArrowLeft':
          event.preventDefault();
          newIndex = currentIndex > 0 ? currentIndex - 1 : enabledTabs.length - 1;
          break;

        case 'ArrowRight':
          event.preventDefault();
          newIndex = currentIndex < enabledTabs.length - 1 ? currentIndex + 1 : 0;
          break;

        case 'Home':
          event.preventDefault();
          newIndex = 0;
          break;

        case 'End':
          event.preventDefault();
          newIndex = enabledTabs.length - 1;
          break;

        default:
          return;
      }

      const newTab = enabledTabs[newIndex];
      if (newTab) {
        handleTabChange(newTab.id);
        // Focus the new tab button
        const tabButton = tabListRef.current?.querySelector(
          `[data-tab-id="${newTab.id}"]`
        ) as HTMLElement;
        tabButton?.focus();
      }
    },
    [activeTab, handleTabChange, tabs]
  );

  const getTabId = (tabId: string) => `${baseId}-tab-${tabId}`;
  const getPanelId = (tabId: string) => `${baseId}-panel-${tabId}`;

  const activeTabContent = tabs.find((tab) => tab.id === activeTab)?.content;

  // Variant-specific styles
  const variantStyles = {
    default: {
      list: cn(
        'border-b border-gray-200 dark:border-gray-700',
        'bg-transparent'
      ),
      tab: (isActive: boolean, isDisabled: boolean) =>
        cn(
          // Base
          'relative px-4 py-3 sm:py-2.5 text-sm font-medium',
          'transition-colors duration-200',
          'focus:outline-none focus-visible:ring-2',
          'focus-visible:ring-primary-500 focus-visible:ring-inset',
          // Bottom border indicator
          'border-b-2 -mb-px',
          // States
          isActive
            ? 'border-primary-600 text-primary-600 dark:border-primary-400 dark:text-primary-400'
            : 'border-transparent text-gray-600 hover:text-gray-900 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200 dark:hover:border-gray-600',
          // Disabled
          isDisabled && 'opacity-50 cursor-not-allowed hover:border-transparent'
        ),
    },
    pills: {
      list: cn('bg-gray-100 dark:bg-gray-800 rounded-lg p-1'),
      tab: (isActive: boolean, isDisabled: boolean) =>
        cn(
          // Base
          'px-4 py-2 sm:py-1.5 text-sm font-medium rounded-md',
          'transition-all duration-200',
          'focus:outline-none focus-visible:ring-2',
          'focus-visible:ring-primary-500 focus-visible:ring-offset-2',
          // States
          isActive
            ? 'bg-white text-gray-900 shadow-sm dark:bg-gray-700 dark:text-gray-100'
            : 'text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-200',
          // Disabled
          isDisabled && 'opacity-50 cursor-not-allowed'
        ),
    },
    underline: {
      list: cn('border-b-2 border-gray-200 dark:border-gray-700'),
      tab: (isActive: boolean, isDisabled: boolean) =>
        cn(
          // Base
          'relative px-4 py-3 text-sm font-medium',
          'transition-colors duration-200',
          'focus:outline-none focus-visible:ring-2',
          'focus-visible:ring-primary-500 focus-visible:ring-inset',
          // States
          isActive
            ? 'text-primary-600 dark:text-primary-400'
            : 'text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300',
          // Underline indicator (positioned element)
          isActive && [
            'after:absolute after:bottom-0 after:left-0 after:right-0',
            'after:h-0.5 after:bg-primary-600 dark:after:bg-primary-400',
            'after:-mb-0.5',
          ],
          // Disabled
          isDisabled && 'opacity-50 cursor-not-allowed'
        ),
    },
  };

  return (
    <div className={className}>
      {/* Tab list */}
      <div
        ref={tabListRef}
        role="tablist"
        aria-orientation="horizontal"
        onKeyDown={handleKeyDown}
        className={cn(
          'flex',
          fullWidth ? 'w-full' : 'w-fit',
          variantStyles[variant].list,
          tabListClassName
        )}
      >
        {tabs.map((tab) => {
          const isActive = tab.id === activeTab;
          const isDisabled = Boolean(tab.disabled);

          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              id={getTabId(tab.id)}
              data-tab-id={tab.id}
              aria-selected={isActive}
              aria-controls={getPanelId(tab.id)}
              aria-disabled={isDisabled}
              tabIndex={isActive ? 0 : -1}
              disabled={isDisabled}
              onClick={() => !isDisabled && handleTabChange(tab.id)}
              className={cn(
                // Touch target
                'min-h-[44px] sm:min-h-0',
                // Full width distribution
                fullWidth && 'flex-1',
                // Flex for icon + label
                'inline-flex items-center justify-center gap-2',
                // Variant styles
                variantStyles[variant].tab(isActive, isDisabled)
              )}
            >
              {tab.icon && (
                <span className="[&>svg]:w-4 [&>svg]:h-4" aria-hidden="true">
                  {tab.icon}
                </span>
              )}
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Tab panels */}
      {tabs.map((tab) => {
        const isActive = tab.id === activeTab;

        return (
          <div
            key={tab.id}
            role="tabpanel"
            id={getPanelId(tab.id)}
            aria-labelledby={getTabId(tab.id)}
            hidden={!isActive}
            tabIndex={0}
            className={cn(
              'focus:outline-none',
              isActive && 'animate-in fade-in duration-200',
              panelClassName
            )}
          >
            {isActive && tab.content}
          </div>
        );
      })}
    </div>
  );
}

/**
 * Controlled Tabs hook for managing tab state externally.
 *
 * @example
 * const { activeTab, setActiveTab } = useTabState('overview');
 * <Tabs tabs={tabs} activeTab={activeTab} onChange={setActiveTab} />
 */
export function useTabState(initialTab: string) {
  const [activeTab, setActiveTab] = useState(initialTab);
  return { activeTab, setActiveTab };
}