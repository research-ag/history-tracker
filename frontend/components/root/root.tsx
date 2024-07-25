import {
  createRoutesFromElements,
  createBrowserRouter,
  Route,
  RouterProvider,
} from "react-router-dom";

import Dashboard from "@fe/components/dashboard";

const router = createBrowserRouter(
  createRoutesFromElements(
    <Route path="/">
      <Route index element={<div>Index</div>} />
      <Route path="dashboard/:canisterId" element={<Dashboard />} />
    </Route>
  )
);

const Root = () => <RouterProvider router={router} />;

export default Root;
