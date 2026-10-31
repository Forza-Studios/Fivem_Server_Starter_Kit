import React, { useState, useRef, useEffect, useMemo } from 'react';
import { useAdminMenu, useChats } from '../../../providers/AdminMenuContext';
import { SubTabs } from '../../ui/SubTabs';
import { SearchField } from '../../ui/SearchField';
import { fetchNui } from '../../../utils/fetchNui';
import { StaffChatMessageArea } from './components/StaffChat/StaffChatMessageArea';
import { StaffChatInput } from './components/StaffChat/StaffChatInput';
import { DmPlayerList } from './components/DMs/DmPlayerList';
import { DmChatWindow, DmEmptyState } from './components/DMs/DmChatWindow';

const StaffChatPage: React.FC = () => {
  const { myName, myId, showCrossmark, players, menuSize, dmHistories, addDM, t } = useAdminMenu();
  const { staffchat } = useChats();
  const filteredPlayers = players.filter((p) => Number(p.ServerId) !== Number(myId));
  const isSmall = menuSize === 'Small';
  const [activeTab, setActiveTab] = useState<'staff' | 'dms'>('staff');
  const [messageInput, setMessageInput] = useState('');
  const [selectedPlayerId, setSelectedPlayerId] = useState<number | null>(null);
  const [dmSearchQuery, setDmSearchQuery] = useState('');
  const [dmInput, setDmInput] = useState('');
  const [sendTimeout, setSendTimeout] = useState(false);
  const [staffSearch, setStaffSearch] = useState('');

  const visibleStaffChat = useMemo(() => {
    const query = staffSearch.toLowerCase();
    if (!query) return staffchat;
    return staffchat.filter(
      (msg) => msg.Message.toLowerCase().includes(query) || msg.Sender.toLowerCase().includes(query),
    );
  }, [staffchat, staffSearch]);
  const chatListRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (activeTab === 'staff' && chatListRef.current) {
      chatListRef.current.scrollTop = chatListRef.current.scrollHeight;
    }
  }, [staffchat, activeTab]);

  const formatMessageTime = () => {
    const d = new Date();
    const h = d.getHours() < 10 ? `0${d.getHours()}` : d.getHours();
    const m = d.getMinutes() < 10 ? `0${d.getMinutes()}` : d.getMinutes();
    return `${h}:${m}`;
  };

  const sendMessage = () => {
    if (sendTimeout) return;
    if (messageInput.trim() !== '') {
      // The server stamps the sender and time, then broadcasts it back.
      fetchNui('sendStaffMessage', { message: messageInput }).catch(() => {});
      setMessageInput('');
    } else {
      setSendTimeout(true);
      showCrossmark();
      setTimeout(() => setSendTimeout(false), 1750);
    }
  };

  const sendDM = () => {
    if (sendTimeout || !selectedPlayerId || !dmInput.trim()) return;
    fetchNui('sendDirectMessage', { targetId: selectedPlayerId, message: dmInput }).catch(() => {});
    const newMsg = { id: Date.now(), text: dmInput.trim(), isMe: true, time: formatMessageTime() };
    addDM(selectedPlayerId, newMsg);
    setDmInput('');
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !sendTimeout) sendMessage();
  };
  const handleDmKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !sendTimeout) sendDM();
  };

  return (
    <div className="flex flex-col h-full w-full relative">
      <div className="p-6 pb-0 flex-shrink-0">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/30 flex items-center justify-center text-accent relative overflow-hidden">
              <div className="absolute inset-0 bg-accent/20"></div>
              <i className="fa-solid fa-user-shield text-2xl relative z-10"></i>
            </div>
            <div>
              <h2 className="text-2xl font-rajdhani font-bold text-primary leading-none tracking-wide uppercase">
                {t('ui.pages.chats.title')}
              </h2>
              <p className="text-xs font-mono text-muted mt-1.5 uppercase tracking-widest opacity-70">
                {t('ui.pages.chats.subtitle')}
              </p>
            </div>
          </div>
          {activeTab === 'staff' && (
            <SearchField
              className="w-64"
              value={staffSearch}
              onChange={setStaffSearch}
              placeholder={t('ui.pages.chats.search_messages')}
            />
          )}
        </div>
      </div>

      {/* Sub Tabs */}
      <div className="border-b border-border/50 pb-4 px-6 pt-2 shrink-0">
        <SubTabs
          tabs={[
            { id: 'staff', label: t('ui.pages.chats.staffchat_tab'), icon: 'fa-solid fa-users' },
            { id: 'dms', label: t('ui.pages.chats.dms_tab'), icon: 'fa-solid fa-envelope' },
          ]}
          activeTab={activeTab}
          onChange={setActiveTab}
        />
      </div>

      {/* Staff Chat Tab */}
      {activeTab === 'staff' && (
        <div className="flex flex-col flex-1 overflow-hidden animate-in fade-in duration-300">
          <StaffChatMessageArea
            staffchat={visibleStaffChat}
            myName={myName}
            chatListRef={chatListRef}
            isFiltered={!!staffSearch}
          />
          <StaffChatInput
            messageInput={messageInput}
            setMessageInput={setMessageInput}
            onSend={sendMessage}
            onKeyPress={handleKeyPress}
            sendTimeout={sendTimeout}
          />
        </div>
      )}

      {/* DMs Tab */}
      {activeTab === 'dms' && (
        <div className="flex-1 flex overflow-hidden animate-in fade-in duration-300">
          {(!isSmall || !selectedPlayerId) && (
            <DmPlayerList
              players={filteredPlayers}
              searchQuery={dmSearchQuery}
              setSearchQuery={setDmSearchQuery}
              selectedPlayerId={selectedPlayerId}
              setSelectedPlayerId={setSelectedPlayerId}
              dmHistories={dmHistories}
              isSmall={isSmall}
            />
          )}
          {(!isSmall || selectedPlayerId) && (
            <div className="flex-1 flex flex-col bg-black/10 relative">
              {!selectedPlayerId ? (
                <DmEmptyState />
              ) : (
                <DmChatWindow
                  selectedPlayerId={selectedPlayerId}
                  players={players}
                  dmHistories={dmHistories}
                  dmInput={dmInput}
                  setDmInput={setDmInput}
                  onSend={sendDM}
                  onKeyPress={handleDmKeyPress}
                  sendTimeout={sendTimeout}
                  isSmall={isSmall}
                  onBack={() => setSelectedPlayerId(null)}
                />
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default StaffChatPage;
