import {
  createRoutesFromElements,
  createBrowserRouter,
  Route,
  RouterProvider,
  useRouteError,
} from "react-router-dom";

import Home from "@fe/components/home";
import Dashboard from "@fe/components/dashboard";
import CMM from "@fe/components/cmm";
import ErrorLayout from "@fe/components/error-layout";

const RootBoundary = () => {
  const error = useRouteError() as { status: number };

  if (error.status === 404) {
    return <ErrorLayout message="Page not found." />;
  }

  return <ErrorLayout message="Unexpected error." />;
};

const router = createBrowserRouter(
  createRoutesFromElements(
    <Route path="/" errorElement={<RootBoundary />}>
      <Route index element={<Home />} />
      <Route path="dashboard/:canisterId" element={<Dashboard />} />
      <Route path="cmm" element={<CMM />} />
    </Route>
  )
);

const Root = () => <RouterProvider router={router} />;

export default Root;
