import { createContext, useContext, useState } from "react";
import { AnonymousIdentity, Identity } from "@dfinity/agent";

interface IdentityContext {
  identity: Identity;
  setIdentity: (value: Identity) => void;
}

const IdentityContext = createContext<IdentityContext>({
  identity: new AnonymousIdentity(),
  setIdentity: () => null,
});

interface IdentityProviderProps {
  children: React.ReactNode;
}

export const IdentityProvider = ({ children }: IdentityProviderProps) => {
  const [identity, setIdentity] = useState<Identity>(new AnonymousIdentity());

  return (
    <IdentityContext.Provider value={{ identity, setIdentity }}>
      {children}
    </IdentityContext.Provider>
  );
};

export const useIdentity = () => useContext(IdentityContext);
